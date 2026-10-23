######################################################################################
# `dcmac_index` is also the GT-quad index — they map 1:1, so the value below
# is the DCMAC hard-block site that anchors that quad. Add a new board by
# appending an entry; no other code changes are needed for the site side.
# Future per-board fields (GT refclk pin, pblock LOC, part string) belong
# in this file alongside the location dict.
######################################################################################

set _dcmac_board_loc [dict create \
    v80 [dict create 0 DCMAC_X1Y1 1 DCMAC_X0Y2] \
]
