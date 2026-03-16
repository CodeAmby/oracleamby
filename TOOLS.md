# TOOLS.md

Environment: Docker container on macOS (Apple Silicon). Local deployment via OpenClaw gateway.

## PDF creation

To create PDFs, use the `md2pdf.sh` or `html2pdf.sh` scripts (pandoc's PDF output fails due to broken LaTeX; these use Chrome headless instead).

- **Markdown → PDF**: `workspace/workspace/scripts/md2pdf.sh <input.md> [output.pdf]`
- **HTML → PDF**: `workspace/workspace/scripts/html2pdf.sh <input.html> [output.pdf]`

Example: Write content to `report.md`, then run `workspace/workspace/scripts/md2pdf.sh report.md` to produce `report.pdf`.
