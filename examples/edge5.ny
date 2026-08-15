def quicksort(lst):
    if len(lst) <= 1:
        return lst
    var pivot = lst[0]
    var left = lst.slice(1).filter(lambda x: x <= pivot)
    var right = lst.slice(1).filter(lambda x: x > pivot)
    var sorted_left = quicksort(left)
    var sorted_right = quicksort(right)
    sorted_left.append(pivot)
    for item in sorted_right:
        sorted_left.append(item)
    return sorted_left

print quicksort([38, 27, 43, 3, 9, 82, 10])
