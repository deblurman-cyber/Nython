var nums = [3, 1, 4, 1, 5, 9, 2, 6]
def bubble_sort(lst):
    var n = len(lst)
    for i in range(n):
        for j in range(n - 1):
            if lst[j] > lst[j + 1]:
                var temp = lst[j]
                lst[j] = lst[j + 1]
                lst[j + 1] = temp
    return lst
print bubble_sort(nums)
