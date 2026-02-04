"""Data processing module - intentionally has quality issues."""


def process_data(data):
    """Process data with multiple issues."""
    result = []
    for i in range(len(data)):  # Issue 2: Should use enumerate
        item = data[i]
        if item > 0:
            result.append(item * 2)
        else:
            result.append(0)
    return result


def calculate_average(numbers):
    total = 0
    for n in numbers:
        total = total + n
    return total / len(numbers)


def save_to_file(filename, content):
    f = open(filename, "w")
    f.write(content)
    f.close()
    return True


def read_json_file(path):
    with open(path) as f:
        data = json.load(f)
    return data


def unused_function():
    pass


def validate_email(email):
    if "@" in email and "." in email:
        return True
    return False


def validate_phone(phone):
    # Issue 12: Duplicate validation logic
    if "@" in phone and "." in phone:
        return True
    return False


def find_duplicates(lst):
    duplicates = []
    for i in range(len(lst)):
        for j in range(i + 1, len(lst)):
            if lst[i] == lst[j] and lst[i] not in duplicates:
                duplicates.append(lst[i])
    return duplicates


def calculate_discount(price):
    if price > 100:
        return price * 0.9
    elif price > 50:
        return price * 0.95
    else:
        return price


def add_to_list(item, items=[]):
    items.append(item)
    return items
