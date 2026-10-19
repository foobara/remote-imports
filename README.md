# Foobara::RemoteImports

Used to import commands/entities/whatever from another system's command connector manifest.

## Installation

Add `foobara-remote-imports` to your Gemfile or .gemspec file and `bundle install`.

Or even just `gem install foobara-remote-imports` if playing with it directly.

## Usage

### Import a command and call it

Require the gem and import a command by its `manifest_url`.

```ruby
require "foobara/remote_imports"

Foobara::RemoteImports::ImportCommand.run!(
  manifest_url: "https://service.example/manifest",
  to_import: "SomeOrg::Math::CalculateExponent"
)

result = SomeOrg::Math::CalculateExponent.run!(base: 2, exponent: 3) # => 8
```

### Importing a manifest you already have locally

If you have the manifest saved as a file, you can skip the fetch.

```ruby
require "json"

manifest = JSON.parse(File.read("manifest.json"))
Foobara::RemoteImports::ImportCommand.run!(
  raw_manifest: manifest,
  to_import: "CalculateExponent"
)
```

### Choosing what to import

`to_import:` accepts any of the following:

- A **command reference**: `SomeOrg::Math::CalculateExponent`
- An **array** of references, to import several commands at once
- **Nothing at all**: omitting `to_import` imports every command in the manifest.

### Commands that need authentication

Some remote commands require you to prove who you are via some form of authentication.

For those commands, pass `auth_header:` as a pair: the header name and its value.

If the server requires a bearer token, you can send that like so:

```ruby
Foobara::RemoteImports::ImportCommand.run!(
  manifest_url: "https://service.example/manifest",
  to_import: "CalculateExponent",
  auth_header: ["Authorization", "Bearer #{ENV.fetch('SERVICE_TOKEN')}"],
  manifest_requires_auth: true
)
```

If the server uses an `X-API-Key` header instead, send it like this:

```ruby
Foobara::RemoteImports::ImportCommand.run!(
  manifest_url: "https://service.example/manifest",
  to_import: "CalculateExponent",
  auth_header: ["X-API-Key", ENV.fetch("SERVICE_API_KEY")],
  manifest_requires_auth: true
)
```

- `auth_header: [header_name, value]` is sent with each call for commands that require authentication.
- `manifest_requires_auth: true` is only for when fetching the manifest itself also needs that header.

### Caching and timeouts

When you import from a `manifest_url:`, the gem saves a copy of the manifest so it doesn't have to fetch it everytime.

- **Cache is on by default**(`cache: true`).
- `cache: false` skips both reading and writing the cache for that import.

## Contributing

Bug reports and pull requests are welcome at [github.com/foobara/remote-imports](https://github.com/foobara/remote-imports).

To work on an existing issue or submit a Pull Request:

1. Fork the repository and clone it to your local machine
2. Run `bundle install` to install dependencies
3. Run `rake` to ensure that everything works as expected before making any changes
4. Implement your changes
5. Re-run `rake` to make sure that all tests and Rubocop pass
6. Commit your changes, push to GitHub and open a Pull Request  for review

## License

This project is licensed under the MPL-2.0 license. Please see [LICENSE.txt](LICENSE.txt) for more information
