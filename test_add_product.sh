TOKEN="eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2hpcmFhanNhaG0uY29tIiwiaWF0IjoxNzczODI3Njk3LCJuYmYiOjE3NzM4Mjc2OTcsImV4cCI6MTc3NDQzMjQ5NywiZGF0YSI6eyJ1c2VyIjp7ImlkIjoiMTgifX19.h9hEwO6p1pnMy9qKZ7y4upPjwFzdFkJ1TrCRqiowGHw"
curl -s -X POST "https://hiraajsahm.com/wp-json/custom/v1/add-product" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Product from CLI",
    "regular_price": "10",
    "description": "testing",
    "category_id": 1,
    "stock_quantity": 10,
    "images": [],
    "status": "publish"
  }'
