# Admin GraphQL recipes (via tools/gql.py)

All scripts: `sys.path.insert(0, "tools"); from gql import gql, paginate, user_errors`. Look things up by **handle** and update-or-create so every script can be re-run. Check `user_errors(result)` after each mutation and fail loudly.

## Read state first
```graphql
{ shop{name currencyCode} publications(first:10){nodes{id name}}
  markets(first:20){nodes{id name handle enabled}} locations(first:20){nodes{id name}} }
```
Snapshot what you'll change to `migration/<thing>-before.json`.

## Products
- Create/update in one call: `productSet(input:$p, synchronous:true){product{id} userErrors{field message}}` with `handle`, `title`, `descriptionHtml`, `status`, `productOptions`, `variants[{optionValues, price, sku, inventoryQuantities}]`, `files[{originalSource, contentType:IMAGE}]`. Pass `identifier:{handle:...}` to upsert by handle.
- Bulk lists: `paginate("products", "id handle status variants(first:100){nodes{id sku price}}", 'query:"status:active"')`.
- Status changes: `productUpdate(product:{id, status:ACTIVE})`.

## Metafields
- Definition once: `metafieldDefinitionCreate(definition:{name, namespace, key, type:"single_line_text_field", ownerType:PRODUCTVARIANT, pin:true})`.
- Values (max 25 per call): `metafieldsSet(metafields:[{ownerId, namespace, key, type, value}])`.

## Collections
`collectionCreate(input:{handle,title,descriptionHtml,image{src},products:[...]})` → `publishablePublish(id, input:{publicationId})` for the Online Store publication.

## Pages, files, policies
- `pageCreate(page:{handle,title,body,isPublished:true})` / `pageUpdate`.
- Re-host images: `fileCreate(files:[{originalSource:url, contentType:IMAGE}])`, poll `node(id){... on MediaImage{image{url}}}` until READY, then rewrite URLs in the body.
- Policies: `shopPolicyUpdate(shopPolicy:{type:SHIPPING_POLICY, body})` — policy text is a client decision.

## Menus
`menus(first:20){nodes{id handle items{...}}}` → `menuUpdate(id,title,handle,items:[{title,type:COLLECTION|PAGE|SHOP_POLICY|HTTP|SEARCH,resourceId|url,items:[...]}])`. Header/footer read admin menus — never hardcode nav in the theme.

## Redirects
`paginate("urlRedirects","id path target")` → `urlRedirectUpdate` / `urlRedirectCreate(urlRedirect:{path,target})`. Shopify only applies a redirect if the path doesn't exist. Ship `migration/redirect-map.csv` as the client deliverable. Verify: `curl -s -o /dev/null -w '%{http_code} %{redirect_url}' https://<domain><path>` → one 301 then 200.

## Markets & prices
- Fixed prices per market: price list `priceListFixedPricesAdd(priceListId, prices:[{variantId, price:{amount,currencyCode}}])`; read with `priceList(id){prices(first:250){nodes{variant{id} price{amount}}}}`.
- Shipping zones decide whether a market can buy at all — check `deliveryProfiles` when a market shows "unavailable".

## Inventory
`inventorySetQuantities(input:{name:"available", reason:"correction", ignoreCompareQuantity:true, quantities:[{inventoryItemId, locationId, quantity}]})`.

## Theme
- `shopify theme list -s <store>`; `shopify theme pull -s <store> -t <id> --path <theme-dir>` before editing if the admin may have changed it.
- `shopify theme push -s <store> -t <id> --path <theme-dir> [--allow-live] [--only <glob>]`. Unpublished preview: `shopify theme push --unpublished`, share `?preview_theme_id=<id>`.
- `shopify theme check --path <theme-dir>` before pushing.

## Storefront verification
Playwright: navigate to `https://<store>/password`, enter the storefront password, then check pages; screenshot desktop (1440) and mobile (390). Use the store's domain + `?country=US` to see another market.
