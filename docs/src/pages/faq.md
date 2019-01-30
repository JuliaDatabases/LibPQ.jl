# Frequently Asked Questions

## Can I use LibPQ.jl with Amazon Redshift?

Yes.
However, LibPQ.jl by default sets some client options to make interactions more reliable.
Unsupported options must be disabled for Redshift to allow connections.
To override all options, pass an empty `Dict{String, String}`:

```julia
conn = LibPQ.Connection("dbname=myredshift"; options=Dict{String, String}())
```
