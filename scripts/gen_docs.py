#!/usr/bin/env python3
"""Convert FRAMEWORK_GUIDE.md into a styled, standalone HTML doc."""

import sys
from pathlib import Path

import markdown

TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<style>
  :root {{
    color-scheme: light dark;
    --bg: #ffffff;
    --fg: #1f2328;
    --muted: #57606a;
    --border: #d0d7de;
    --code-bg: #f6f8fa;
    --link: #0969da;
    --accent: #0969da;
  }}
  @media (prefers-color-scheme: dark) {{
    :root {{
      --bg: #0d1117;
      --fg: #e6edf3;
      --muted: #9198a1;
      --border: #30363d;
      --code-bg: #161b22;
      --link: #4493f8;
      --accent: #4493f8;
    }}
  }}
  * {{ box-sizing: border-box; }}
  body {{
    margin: 0;
    background: var(--bg);
    color: var(--fg);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
    line-height: 1.6;
  }}
  .wrap {{
    max-width: 900px;
    margin: 0 auto;
    padding: 2.5rem 1.5rem 5rem;
  }}
  h1, h2, h3, h4 {{
    line-height: 1.25;
    font-weight: 600;
    scroll-margin-top: 1rem;
  }}
  h1 {{
    font-size: 2rem;
    border-bottom: 1px solid var(--border);
    padding-bottom: 0.4rem;
  }}
  h2 {{
    font-size: 1.5rem;
    border-bottom: 1px solid var(--border);
    padding-bottom: 0.3rem;
    margin-top: 2.5rem;
  }}
  h3 {{ font-size: 1.2rem; margin-top: 2rem; }}
  a {{ color: var(--link); text-decoration: none; }}
  a:hover {{ text-decoration: underline; }}
  code {{
    background: var(--code-bg);
    padding: 0.15em 0.4em;
    border-radius: 6px;
    font-size: 0.9em;
    font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  }}
  pre {{
    background: var(--code-bg);
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 1rem;
    overflow-x: auto;
  }}
  pre code {{ background: none; padding: 0; }}
  table {{
    border-collapse: collapse;
    width: 100%;
    margin: 1rem 0;
    display: block;
    overflow-x: auto;
  }}
  th, td {{
    border: 1px solid var(--border);
    padding: 0.5rem 0.8rem;
    text-align: left;
  }}
  th {{ background: var(--code-bg); }}
  blockquote {{
    margin: 1rem 0;
    padding: 0.2rem 1rem;
    border-left: 4px solid var(--accent);
    color: var(--muted);
  }}
  .toc {{
    background: var(--code-bg);
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 1rem 1.5rem 1.25rem;
    margin-bottom: 2.5rem;
  }}
  .toc .toctitle {{
    display: block;
    font-weight: 600;
    font-size: 1.1rem;
    margin-bottom: 0.5rem;
  }}
  .toc ul {{
    margin: 0.3rem 0 0;
    padding-left: 1.2rem;
    list-style: none;
  }}
  .toc > ul {{ padding-left: 0; }}
  .toc li {{ margin: 0.25rem 0; }}
  .toc a {{ color: var(--fg); }}
  .toc a:hover {{ color: var(--link); }}
  .generated-note {{
    color: var(--muted);
    font-size: 0.85rem;
    margin-top: 3rem;
    border-top: 1px solid var(--border);
    padding-top: 1rem;
  }}
</style>
</head>
<body>
<div class="wrap">
{body}
<p class="generated-note">Generated from <code>{source}</code> via <code>make docs</code>. Do not edit directly.</p>
</div>
</body>
</html>
"""


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} <input.md> <output.html>", file=sys.stderr)
        return 1

    src_path = Path(sys.argv[1])
    out_path = Path(sys.argv[2])

    md_text = src_path.read_text(encoding="utf-8")

    md = markdown.Markdown(
        extensions=["extra", "toc", "sane_lists", "admonition"],
        extension_configs={"toc": {"title": "Contents", "toc_class": "toc"}},
    )
    body_html = md.convert(md_text)

    title = md.Meta.get("title", [src_path.stem])[0] if getattr(md, "Meta", None) else src_path.stem

    # Keep the leading title/subtitle above the fold and drop the index in
    # right after them, ahead of the first section (split on the first <hr>,
    # which marks the end of the title block in FRAMEWORK_GUIDE.md).
    header, sep, rest = body_html.partition("<hr />")
    if sep:
        body_html = f"{header}{sep}\n{md.toc}{rest}"
    else:
        body_html = f"{md.toc}{body_html}"

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(
        TEMPLATE.format(title=title, body=body_html, source=src_path.as_posix()),
        encoding="utf-8",
    )
    print(f"✅ Generated {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
