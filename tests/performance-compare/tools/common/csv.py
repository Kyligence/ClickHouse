import os

DATA_SPLIT_CHAR = ","


def write_result(dirs, stats_entries):
    with open(dirs + os.sep + "detail.csv", "w") as detail:
        with open(dirs + os.sep + "aggregated.csv", "w") as aggregated:
            aggregated.write("name" + DATA_SPLIT_CHAR + "avg_response_time" + DATA_SPLIT_CHAR +
                             "median_response_time" + DATA_SPLIT_CHAR + "min_response_time" + DATA_SPLIT_CHAR +
                             "max_response_time")
            aggregated.write("\n")
            for key in stats_entries:
                entry = stats_entries[key]
                detail.write(key[0] + DATA_SPLIT_CHAR + locust_group_to_times(entry.response_times))
                detail.write("\n")
                aggregated.write(key[
                                     0] + DATA_SPLIT_CHAR + str(
                    int(entry.avg_response_time / 1000)) + DATA_SPLIT_CHAR + str(
                    int(entry.median_response_time / 1000)
                ) + DATA_SPLIT_CHAR + str(int(entry.min_response_time / 1000)) + DATA_SPLIT_CHAR +
                                 str(int(entry.max_response_time / 1000)))
                aggregated.write("\n")


def locust_group_to_times(dicts):
    result = ""
    for elapsed in dicts:
        if result == "":
            result = append_times(dicts[elapsed], elapsed)
        else:
            result += DATA_SPLIT_CHAR + append_times(dicts[elapsed], elapsed)

    return result


def append_times(times, elapsed):
    r = ""
    for i in range(times):
        if i == 0:
            r = str(int(elapsed / 1000))
        else:
            r += DATA_SPLIT_CHAR + str(int(elapsed / 1000))
    return r


def read_csv_result(file):
    dicts = {}
    with open(file, "r") as file:
        lines = file.read().splitlines()

    for line in lines:
        if line != "":
            data = line.split(DATA_SPLIT_CHAR)
            dicts[data[0]] = [int(x) for x in data[1].split(DATA_SPLIT_CHAR)]

    return dicts
