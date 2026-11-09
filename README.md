# Foobara::RemoteImports

Used to import commands/entities/whatever from another system's command connector manifest.

## Installation

Add `gem "foobara-remote-imports"` to your Gemfile or .gemspec file and `bundle install`.

Or even just `gem install foobara-remote-imports` if just playing with it directly in the scripts.

## Usage

### Import a command and call it

Require the gem and import a command by its **full manifest reference**.

```ruby
require "foobara/remote_imports"

commands = Foobara::RemoteImports::ImportCommand.run!(
  manifest_url: "https://service.example/manifest",
  to_import: "SomeOrg::Math::CalculateExponent"
)

calculate_exponent = commands.first
outcome = calculate_exponent.new(base: 2, exponent: 3).run
puts outcome.result if outcome.success? # => 8
```

### Importing twice

If a command with that name has already been imported in the current program, it's **skipped**. So importing the same command again will return an **empty array**.

### Importing a manifest you already have locally

If you have the manifest saved as a file, you can skip the fetch.

```ruby
require "json"

manifest = JSON.parse(File.read("manifest.json"))
commands = Foobara::RemoteImports::ImportCommand.run!(
  raw_manifest: manifest,
  to_import: "CalculateExponent"
)
```

Pass exactly one of `manifest_url:` or `raw_manifest:`, not both and not neither. 

The raw manifest must still contain the `metadata["url"]` to let the imported commands know where the remote system is.

### Choosing what to import

`to_import:` accepts any of the following:

- A **full command reference**: `SomeOrg::Math::CalculateExponent`
- A **unique suffix**: `CalculateExponent`
- An **array** of references, to import several commands at once
- **Nothing at all**: omitting `to_import` imports every command in the manifest.

### Commands that need authentication

Some remote commands require you to prove who you are via some form of authentication. For those commands, pass `auth_header:` as a pair: the header name and its value.

```ruby
commands = Foobara::RemoteImports::ImportCommand.run!(
  manifest_url: "https://service.example/manifest",
  to_import: "CalculateExponent",
  auth_header: ["Authorization", "Bearer #{ENV.fetch('SERVICE_TOKEN')}"],
  manifest_requires_auth: true
)
```

- `auth_header: [header_name, value]` is sent with each call for commands that require authentication.
- `manifest_requires_auth: true` is only for when fetching the manifest itself also needs that header, otherwise if only the command needs it, you can leave it out.

### Caching and timeouts

When you import from a `manifest_url:`, the gem saves a copy of the manifest so it doesn't have to fetch it everytime.

- **Cache is on by default**(`cache: true`). Fetched manifests are stored as JSON under `tmp/cache.foobara-remote-imports`, keyed by the manifest URL.
- **There is no expiry or refresh option**. Therefore a cached manifest is reused as is.
- `cache: false` skips both reading and writing the cache for that import. It doesnot replace a class you've already imported and doesnot update an old cache entry.
- **Timeout**: By default, fetching a manifest waits up to **30 seconds**. To change this, set the environment variable `FOOBARA_HTTP_MANIFEST_TIMEOUT` to a whole number of seconds.

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
