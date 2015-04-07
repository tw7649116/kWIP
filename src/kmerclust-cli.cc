/*
 * Copyright 2015 Kevin Murray <spam@kdmurray.id.au>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "kmerclust.hh"

using namespace kmerclust::metrics;  // Imports the DistanceCalcXXX classes


template<typename DistMeasure>
int
run_main(DistMeasure &distcalc, int argc, const char *argv[])
{
    std::vector<std::string> filenames;

    for (int i = 1; i < argc; i++) {
        filenames.push_back(std::string(argv[i]));
    }

    distcalc.calculate_pairwise(filenames);
    distcalc.print_dist_mat();
    return EXIT_SUCCESS;
}

void
print_valid_measures()
{
    std::cerr << "Valid measures are:" << std::endl;
    std::cerr << "  d2" << std::endl
              << "  d2pop" << std::endl
              << "  js" << std::endl;
}

int
main (int argc, const char *argv[])
{
    if (argc < 3) {
        std::cerr << "USAGE: " << argv[0] << " <distmeasure> <hashtable> ..."
                  << std::endl;
        print_valid_measures();
        return EXIT_FAILURE;
    }

    if (strcmp(argv[1], "d2") == 0) {
        DistanceCalcD2 dist;
        return run_main<DistanceCalcD2>(dist, argc - 1, argv + 1);
    } else if (strcmp(argv[1], "d2pop") == 0) {
        DistanceCalcD2pop dist;
        return run_main<DistanceCalcD2pop>(dist, argc - 1, argv + 1);
    } else if (strcmp(argv[1], "js") == 0) {
        DistanceCalcJS dist;
        return run_main<DistanceCalcJS>(dist, argc - 1, argv + 1);
    }

    // If we get to here, we have an error
    std::cerr << "ERROR: Invalid distance measure name " << argv[1]
              << std::endl << std::endl;
    print_valid_measures();
    return EXIT_FAILURE;
}
