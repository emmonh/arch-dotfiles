import argparse
import os
import sys

from ascii_magic import AsciiArt


def getParser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="get_ascii_art",
        description="Create an ASCII Art .txt file from an image, ready to use within fastfetch.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )

    parser.add_argument(
        "input",
        help="Path to image to be converted",
    )

    parser.add_argument(
        "-o",
        "--output",
        default="~/rice/shell_ascii_art.txt",
        help="Output file",
    )

    parser.add_argument(
        "--color",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Include color control characters (--color / --no-color)",
    )

    parser.add_argument(
        "--enhance",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Enhance image before generating ASCII Art (--enhance / --no-enhance)",
    )

    parser.add_argument(
        "-c",
        "--columns",
        type=int,
        default=80,
        help="Width in columns of the resulting ASCII Art",
    )

    return parser


def main():
    parser = getParser()
    args = parser.parse_args()

    image_path = os.path.expanduser(args.input)
    text_out = os.path.expanduser(args.output)
    enhance = args.enhance
    cols = args.columns
    is_monochrome = not args.color

    if cols <= 0:
        parser.error("--columns must be a positive integer")

    if not os.path.isfile(image_path):
        sys.exit(f"Error: input image not found: {image_path}")

    out_dir = os.path.dirname(text_out)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)

    try:
        ascii_art = AsciiArt.from_image(image_path)
        ascii_art.to_file(
            path=text_out,
            columns=cols,
            enhance_image=enhance,
            monochrome=is_monochrome,
        )
    except Exception as exc:
        sys.exit(f"Error: failed to generate ASCII Art: {exc}")

    print(f"ASCII Art written to {text_out}")


if __name__ == "__main__":
    main()
