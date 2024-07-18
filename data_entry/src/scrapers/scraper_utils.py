import re


def apply_regex(text, pattern, transform_function):
    """
    Apply a transformation function to all regex matches in a string.

    Args:
    text (str): The input string to be processed.
    pattern (str): The regular expression pattern to match.
    transform_function (callable): A function to apply to each match.

    Returns:
    str: The input string with transformations applied to all matches.
    """
    result = []
    last_end = 0

    for match in re.finditer(pattern, text):
        start, end = match.span()

        # Append the text before the match
        result.append(text[last_end:start])

        # Apply the transformation function to the matched text and append
        transformed_text = transform_function(text[start:end])
        result.append(transformed_text)

        last_end = end

    # Append any remaining text after the last match
    result.append(text[last_end:])

    return "".join(result)
