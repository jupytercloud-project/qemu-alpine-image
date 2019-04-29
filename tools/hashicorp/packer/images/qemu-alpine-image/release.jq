# iterate over array
.[]
# only keep the virtual entry
| select(.title=="Virtual")
# inject mirror value
| . + { "mirror": $mirror }
# sanitize numbers to strings
| walk(if type == "number" then tostring else . end)
