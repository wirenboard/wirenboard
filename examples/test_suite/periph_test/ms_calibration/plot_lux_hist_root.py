#!/usr/bin/python
import ROOT

import sys, math


h = ROOT.TH1D("lux_hist", "Lux histogram", 100, 3500, 5500)

for line in open(sys.argv[1]):
    line = line.strip()
    if line:
        val = float(line)
        h.Fill(val)


h.Draw()
# c2 = ROOT.TCanvas("c2")
# c2.cd()
# h_raw.Draw()

# MS v3 lux
  # EXT PARAMETER                                   STEP         FIRST   
  # NO.   NAME      VALUE            ERROR          SIZE      DERIVATIVE 
  #  1  Constant     6.95387e+00   1.06192e+00   1.58117e-03   8.43938e-06
  #  2  Mean         4.97066e+03   1.33702e+01   2.92706e-02  -2.43044e-07
  #  3  Sigma        1.14543e+02   1.62661e+01   7.21629e-05   1.44832e-04

# 1 sigma   4970 +/ - 114  2.2%
# 2 sigma   4970 +/ - 230  4.5%



# === MSW2 lux
  # NO.   NAME      VALUE            ERROR          SIZE      DERIVATIVE 
  #  1  Constant     8.48998e+00   8.74848e-01   2.23284e-03   1.91638e-04
  #  2  Mean         4.39074e+03   1.46097e+01   5.11533e-02   1.94025e-06
  #  3  Sigma        1.77262e+02   1.52851e+01   6.69081e-05   6.91235e-03

# 1 sigma 4391 +/- 177  4%
# 2 sigma 4391 +/- 354  8%