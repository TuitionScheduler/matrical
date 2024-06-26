import re

def apply_regex(string, regex, funct):
    result = string

    delta = 0
    for match in re.finditer(regex, string):
        i, j = match.span()
        i, j = i + delta, j + delta
        temp = len(result)
        result = result[:i] + funct(result[i:j]) + result[j:]
        delta += len(result) - temp

    return result