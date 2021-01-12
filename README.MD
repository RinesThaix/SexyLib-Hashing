# SexyLib-Hashing

## Overview
This is a module that allows you to access hashing algorithms inside your addon.

Currently supports *CRC32*, *SHA256* and *RSA*.

## Requirements
- **SexyLib-Core** is required.
- **LibStub** is required.
- **LibDeflate** is required.
- **AceSerializer-3.0** is required.

## Usage

`Sha256(msg)` - calculate *SHA256* of the given string.
- `msg` - string over which *SHA256* must be calculated.

`SexyLib:Hashing()` - retrieve hashing API instance to work with from your addon.

`hashing:Crc(str, length)` - calculate *CRC32* of the given string and take it's hexdigest trimmed to the given length.
- `str` - string over which *CRC32* must be calculated.
- `length` - the length to which hexdigest of the crc will be trimmed.

`hashing:Sign(value, privateKey, publicKey)` - calculate signature of the input value for given keys.
- `value` - the value over which signature must be calculated.
- `privateKey` and `publicKey` - see exact definition inside function `DSA_test` at the end of `dsa.lua` file.
- `Returns` two values:
  - `signature` - expected result.
  - `error` - string, if something went wrong.

`hashing:Validate(value, signature, publicKey)` - validate signature of the input value for given public key.
- `value` - the value for which we're validating signature.
- `signature` - already calculated signature of the value.
- `publicKey` - see exact definition inside function `DSA_test` at the end of `dsa.lua` file.

## Included libraries
- **LUA Big Number Library** by Jayden Koedijk (elcius@gmail.com)
- **LUA Digital Signature Algorithm Library** by by Jayden Koedijk (elcius@gmail.com)