#!/usr/bin/env python3
"""Shopify Admin GraphQL via `shopify store execute` (uses the CLI's store auth — no tokens in files).

Library:  from gql import gql, paginate
          gql("{shop{name}}");  for p in paginate("products", "id handle status"): ...
CLI:      gql.py '{shop{name}}'            gql.py @query.graphql -v '{"id":"gid://..."}'
Store comes from -s, $SHOPIFY_STORE, or "store" in .shopify-project.json (searched upward from cwd).
Mutations whose name ends in "Delete" are refused unless SHOPIFY_ALLOW_DELETE=1.
"""
import json, os, re, shutil, subprocess, sys, time
from pathlib import Path


def project_config():
    for d in [Path.cwd(), *Path.cwd().parents]:
        f = d / ".shopify-project.json"
        if f.exists():
            return json.loads(f.read_text())
    return {}


STORE = os.environ.get("SHOPIFY_STORE") or project_config().get("store")


def gql(query, variables=None, store=None):
    store = store or STORE
    if not store:
        sys.exit("No store: pass -s, set SHOPIFY_STORE, or add .shopify-project.json")
    if re.search(r"\b\w+Delete\s*\(", query) and os.environ.get("SHOPIFY_ALLOW_DELETE") != "1":
        sys.exit("Refusing a *Delete mutation — ask the user, then rerun with SHOPIFY_ALLOW_DELETE=1")
    cmd = [shutil.which("shopify") or "shopify", "store", "execute", "-s", store, "-j", "--query", query]
    if query.lstrip().startswith("mutation"):
        cmd.append("--allow-mutations")
    if variables:
        cmd += ["--variables", json.dumps(variables)]
    for attempt in range(5):  # retry transient network / throttle errors
        out = subprocess.run(cmd, capture_output=True, text=True)
        try:
            data = json.loads(out.stdout)
        except json.JSONDecodeError:
            time.sleep(3 * (attempt + 1))
            continue
        if isinstance(data, dict) and data.get("errors") and "THROTTLED" in json.dumps(data["errors"]):
            time.sleep(5 * (attempt + 1))
            continue
        return data.get("data", data)
    sys.exit(f"GraphQL call failed:\n{out.stdout}\n{out.stderr}")


def paginate(connection, fields, args="", variables=None, store=None):
    """Yield every node of a top-level connection, e.g. paginate("products", "id handle", 'query:"status:active"')."""
    cursor = None
    while True:
        extra = f", {args}" if args else ""
        q = f'query($c:String){{ {connection}(first:250, after:$c{extra}){{ nodes{{ {fields} }} pageInfo{{hasNextPage endCursor}} }} }}'
        r = gql(q, {**(variables or {}), "c": cursor}, store)[connection]
        yield from r["nodes"]
        if not r["pageInfo"]["hasNextPage"]:
            return
        cursor = r["pageInfo"]["endCursor"]


def user_errors(result):
    """Return userErrors from any mutation payload in a gql() result (empty list = success)."""
    return [e for v in result.values() if isinstance(v, dict) for e in v.get("userErrors") or []]


if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("query", help="GraphQL string or @file.graphql")
    ap.add_argument("-v", "--variables", help="JSON string or @file.json")
    ap.add_argument("-s", "--store")
    a = ap.parse_args()
    q = Path(a.query[1:]).read_text() if a.query.startswith("@") else a.query
    v = None
    if a.variables:
        v = json.loads(Path(a.variables[1:]).read_text() if a.variables.startswith("@") else a.variables)
    print(json.dumps(gql(q, v, a.store), indent=2))
