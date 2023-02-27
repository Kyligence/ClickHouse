import argparse
import sys
from itertools import combinations

import numpy as np
import statsmodels.stats.weightstats as st
from common import csv

# TODO:
# Clickhouse method:
# This method ultimately gives a single threshold number T:
#     what is the largest difference in median query run times between old and new server,
#     that we can observe even if nothing has changed.
# Then we have a simple decision protocol given this threshold T and the measured difference of medians D:
#
# abs(D) <= T — the changes are not statistically significant,
# abs(D) <= 5% — the changes are too small to be important,
# abs(T) >= 10% — the test query has excessive run time variance that leads to poor sensitivity,
# finally, abs(D) >= T and abs(D) >= 5% — there are statistically significant changes of significant magnitude.


parser = argparse.ArgumentParser(description='command line arguments')
parser.add_argument('--original-file', type=str, help='', required=True)
parser.add_argument('--compare-file', type=str, help='', required=True)

alpha = 0.05


def randomization_test(original_list, compare_list, s_name):
    total_list = original_list + compare_list
    observed_diff = np.mean(compare_list) - np.mean(original_list)
    total = 0
    x = 0

    for i in combinations(total_list, len(original_list)):
        total += 1
        original_temp_list = list(i)
        compare_temp_list = [item for item in total_list if item not in set(original_temp_list)]
        original_temp_mean = np.mean(original_temp_list)
        compare_temp_mean = np.mean(compare_temp_list)
        mean_dif_temp = compare_temp_mean - original_temp_mean
        if mean_dif_temp <= observed_diff:
            x += 1

    p = x / total

    print(s_name, "p=", p)

    if p >= alpha:
        return False
    else:
        return True


def tow_sample_t_test(original_list, compare_list, s_name):
    t, p, df = st.ttest_ind(original_list, compare_list,
                            usevar='unequal')
    print(s_name, "p=", p, "t=", t)
    if p >= alpha:
        return False
    else:
        return True


if __name__ == "__main__":
    args = vars(parser.parse_args())
    original_data = csv.read_csv_result(args["original_file"])
    compare_data = csv.read_csv_result(args["compare_file"])

    for sql_name in original_data:
        if not compare_data[sql_name]:
            continue
        randomization_test(original_data[sql_name], compare_data[sql_name], sql_name)
        tow_sample_t_test(original_data[sql_name], compare_data[sql_name], sql_name)
