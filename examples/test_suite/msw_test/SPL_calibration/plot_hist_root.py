#!/usr/bin/python
import ROOT

import sys, math

#MIC_HMO1003A
SND_DB_COEFF_A = 13.00
SND_DB_COEFF_B = 9.30


h = ROOT.TH1D("spl_hist", "SPL histogram", 80, 70, 90)
h_raw = ROOT.TH1D("spl_hist_raw", "SPL raw histogram", 48, 300, 2000)

for line in open(sys.argv[1]):
    line = line.strip()
    if line:
        val = float(line)
        h.Fill(val)

        val_raw = math.exp((val - SND_DB_COEFF_A) / SND_DB_COEFF_B )
        h_raw.Fill(val_raw)



h.Draw()
c2 = ROOT.TCanvas("c2")
c2.cd()
h_raw.Draw()

# spl = B * log(spl_raw) + A
# exp(( spl - A ) / B ) = spl_raw


# ==========  MSW2 MIC_HMO1003A ==========
# spl raw: 
   # 1  Constant     1.39120e+01   1.41629e+00   3.16056e-03  -1.32652e-06
   # 2  Mean         1.20299e+03   1.62019e+01   4.63107e-02  -9.91059e-07
   # 3  Sigma        1.92081e+02   1.46674e+01   5.56312e-05   8.10981e-04

# old SPL interval 78 +/- 3 == [75, 81]

# 1 sigma interval: [77.34, 80.33]
# 2 sigma interval: [75.39, 81.53]



# =========== MS v3.2 MIC_HMO1003A ==========
  # EXT PARAMETER                                   STEP         FIRST   
  # NO.   NAME      VALUE            ERROR          SIZE      DERIVATIVE 
  #  1  Constant     8.86929e+00   1.12563e+00   1.47878e-03  -1.07781e-04
  #  2  Mean         9.55727e+02   1.83830e+01   3.10700e-02   2.31563e-07
  #  3  Sigma        1.69711e+02   1.63638e+01   4.26022e-05   4.80455e-04


# old SPL interval [73, 79]

# 1 sigma interval: [75.0, 78.3]
# 2 sigma interval: [72.7, 79.6]


