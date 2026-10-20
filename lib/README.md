# Python Bundled Dependencies (`lib/`)

This directory contains pre-bundled Python dependencies for offline deployment environments such as Zoho Catalyst AppSail.

## Standard Installation

For local development or standard server deployments, install dependencies using `pip`:

```bash
pip install -r requirements.txt
```

Or for production deployments:

```bash
pip install -r requirements-prod.txt
```

## Zoho Catalyst AppSail Pre-Bundling

When deploying to Zoho Catalyst AppSail without a custom build container, pre-bundled Linux x86_64 wheels can be staged into `lib/`:

```bash
pip install -r requirements-prod.txt --target ./lib --platform manylinux2014_x86_64 --only-binary=:all:
```

The application entry points (`main.py` and `scripts/run_catalyst.py`) automatically detect and prepend `./lib` to `sys.path` if present.
