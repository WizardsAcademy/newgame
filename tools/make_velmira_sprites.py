#!/usr/bin/env python
"""Generate Velmira's 6-frame hero sheet (player_shabnam.png).

FOURTH design - the player's own pixel-art reference, recovered at full
96x96 resolution. The cleaned reference bitmap is pasted into this file as
a run-length-encoded base (BASE_PAL + BASE_RLE), and the six frames are
derived from it in code, so a change to one edit moves the sheet in one run:

    python tools/make_velmira_sprites.py

Writes:
    assets/textures/player_shabnam.png   576 x 96 (6 frames of 96x96)
    docs/images/velmira_preview.png      review sheet

SHEET LAYOUT  (matches scenes/player/Shabnam.tscn - do not reorder!)
    frame 0 : idle                  (the base bitmap, untouched)
    frame 1 : walk A                (right leg lifted, 1 px body bob)
    frame 2 : walk B                (left leg lifted, 1 px body bob)
    frame 3 : attack A              (blazing eyes + blood bead at the chest)
    frame 4 : attack B              (arm thrust right + droplet fan)
    frame 5 : idle blink            (the lids shut for one beat)

The .py is the source of truth, never the PNG.
"""

from PIL import Image, ImageDraw

FRAME = 96
FRAMES = 6

# ---------------------------------------------------------------------------
# Palette recovered from the reference: quantised to 28 tones, then merged
# down to 17 flat house-style tones. Most-used first; index i is symbol
# SYMS[i] in BASE_RLE.
# ---------------------------------------------------------------------------
BASE_PAL = [
    (47, 31, 50, 255),
    (27, 18, 29, 255),
    (8, 5, 8, 255),
    (37, 25, 40, 255),
    (15, 9, 16, 255),
    (23, 13, 22, 255),
    (99, 15, 41, 255),
    (42, 28, 45, 255),
    (233, 197, 204, 255),
    (60, 7, 25, 255),
    (33, 4, 15, 255),
    (70, 49, 67, 255),
    (73, 10, 31, 255),
    (166, 128, 142, 255),
    (87, 13, 36, 255),
    (38, 8, 20, 255),
    (54, 24, 43, 255),
]

# extra tones used only by the derived frames
EXTRA = {
    "iris_hi": (240, 96, 120, 255),   # blazing cast eyes
    "blood": (190, 30, 60, 255),      # the blood bead / droplets core
    "blood_hi": (240, 90, 120, 255),  # bead highlight
    "white": (255, 255, 255, 255),    # bead glint / fang
}

SYMS = "ABCDEFGHIJKLMNOPQ"

BASE_RLE = [
    "",
    "",
    "",
    "",
    "",
    ".37E5CE4C",
    ".37H4D4H2B",
    ".33FB6E.5FE.CD3.2F",
    ".33BA3B2FE.E3.E2.CBE2.2BFEFE",
    ".31C2DAD2E.2CEDB3C.3C.FBF.FBDBC",
    ".31BHA2E.3EA3F2DFC.2CBDHDB.2BH2E",
    ".29EFDAHC.2EALA3B3F2ECFDH4B2.BA2FC.12P2",
    ".29FDH2B.CDAL2AD2F2EC2EB2DH6B.BHDE.12MJ",
    ".29FD2B.2CAL2A2B2C.C2.2CB2CEH4DC.DBE.12MJ",
    ".24KG3K.3CFBEAL2HDB.2ED2B.2EC.2BH3A2F.FB2.9KG4C",
    ".24KMK2O2M.EB2CDL2ADC.BDH2DBE.4CDH2A2B.EBD.10CM2C",
    ".25CPMG3.2CMPEDLAE.BH2AHD2B.CEFE2DHALACE2B2E.9MJ",
    ".23CJCMGO2GOP.CGKFA2.FA2HA2C.B4DBCEHAL2EBCB2E.9JP",
    ".23MJPG2K.G2OPCGKED.CL3A2B.2CB3A2DF2L3FC2BDE",
    ".20JMK2.OGKMKGOGOKGP.CEAL4A.EFE2DHA2BFCL4CECFE.21CM2P",
    ".20PMO.KGKCMO.MGJPG2P.EAL3ADEDBF.2DA2DBCAL3BE.E2.20OGOC",
    ".21COCKO.OMG.OGCPOPC.EHALAHEBAB.E.DA4E.LA3.2C2.6PJ5.7OG2P",
    ".22OPKGMCJPCGMPGM.2CDH2A2EFA2B.F2CA4B.HA3.10CJG3OKC.4KG3C",
    ".19E2C2PMO2PC2O2CJGM.2CH4AEFA2B.E2CA5EDA3DB.10CMOG2J.3KG2J2C",
    ".19DHB.KJO3K2J.M2PK.EBHDFAB.DA2C4.EA4ECDA3B.11JOG3K2MKG2K",
    ".19ED2C.CO2.JO2G2J.2B3HB2AF.A3.N3E.AHDABCBA2FAC.F2.7J.JG7OK",
    ".20BDE.5O3P2C.CBD3EBAF.A2HLI2N2.A2DHBCBA2CDHBFE.9J2COG2OP",
    ".24JK.3J2.4DA3DEDAF.A2.NI3N.DA.FBFBA2H.DAEC.13G2J",
    ".23JOK.JC.5BA4B2DHE.A2.I4NFEACEB2EBA2.DAHDE.12MJ",
    ".12CK.7CPJP.JOM.EB.2A4BCDAD.2HA.I5NCADFEBEBA2C.BHAB.12CP",
    ".12PO.7PGJ.KOGO.E.FBA3BCEA2DBCFA.I4N2CDAD.EF.DA2C.EA2F",
    ".12PO.6PG2O.CJG2.2FA4D.CDABHNHFA.I2NL.4DABCE.DA2C.CHADC",
    ".11MOGOK.3COG2M.2KGO.CA4DC2BAD.AIAFH.I3N4.DA2FC.D2AC.2FA2F",
    ".11PMOPC.5JG.4CPFA3DF.CHA2BLNIACDEI6N.BA3F.BDABC.CEHF",
    ".12PO.8J.6BDB3.EH2DFAI3NLBFI7N.DA2HF.DHAE.3DF",
    ".12PM.8C.F2CEC.EF2.EDB2EFLN5B2NI2N2LQ2DC2FA2CHDAECF.BE",
    ".24BFBDE.5CE.6FQN2FDCI2NLE.6F6.CE.FC",
    ".23FC.B2N4D.EC.BD.C.3LNLBFI2A.3C.BF.3DBN4.B",
    ".22BDC.B2DN3.2B2.L2CPK2DLI2NHDNLBPCPCLA.BAH.N3A.D",
    ".22BE.2BAFLN2.EB2.N2MGO2LI4N3ILGMGJNL.BA2.N2L.2BE",
    ".20CDB.2CBHB.BN.BDB.LN2G3NI8NG3N2L.BA2.NB.3B2",
    ".18FA2B.3BH2BC2.2AHBF.LI2NI11N4A.EHA2.2EC.2B2F",
    ".18FAHF.3DA2BCE.2AHB2.2LI16F.2BAHC.CBE.3FBC",
    ".16DHADBE.2FHA2BCBC.A2HB.ANI5N5I6N.EHAF.2CBE.3FDB",
    ".15CLAEC.2C.HA2BEF2C.A3H.CLN2I3N4LI4N2LEDAB.2CB2F.4CBDBFC",
    ".14A3C.4BCDA2.FBE.2FA3.4LI12L.2BAD.3CB2DE.4CEBABE",
    ".14AL.6BA3F2B2E.E3A2B.4EFHI6LF2.3BAD.3CB2DHF.5EA3F",
    ".14HC.6DA2BEB3E.2F2.CAB.5CA2L2A2E.5BAHBC.2CB2DB.2B.4FHE",
    ".14DC.4EDA2DEBD2C.3FBF.ADCJ2PC.2CQLC.2CJ3.2CA2F.3EBHA2EB.4FDE",
    ".15BE.2BA3DCEBD2.4CFD2ADCMJ2K.3L2.3KJMG2K.D2AD.2CBDA2B.4CBDE.3KO",
    ".15EBFBA3DCEDHAD.5EA3FKG2K.CFDLGHE2.KG4O.EA2E.2FBDA3.2CB3C.3KO",
    ".16DA3HBC2BDA2D.2BEA3DBKMOGCF2DNG2LBF2.G2JC2.2BAB.2EB2DA2E.CB2E.3MG3K",
    ".15BA2HDBC2BA2DBE.BDB2D2.4KMPHABLOMQDA2POP.5EABE.2CBDA3C2F.6KO",
    ".14EA3B2F.FBA2BC.DA2.5C2FE.PAL2BL2BL3PC2FC2.2EHB2C.2FDA4E.7KO",
    ".8F5BHABFBEC2DA3E.2AC.5EF3EC3NI2L2I2NC.CF2CFCED2BE.3FD2A3D",
    ".8DA4E.2EBF.2BA4E.2A.8CBDHDCFDNIN2DF.EDADEC.BABC.2FCFBDA5E",
    ".8DA2D2C.2B2C.CDA4D.2DB.3FE.2FDADFP.HBL2DABKPEBD2FCHB.C2.BE.CDHBA3BC",
    ".8BA2.4FBF.CA6B.2EDF2EFC.CDHB.CJ.BDEFBDEPMK.EB2C.3F2B2E.CDHDBA3HDE",
    ".9A2.4B2E.CA5DB.3D3BF.2BHDECKO.CEBLEC.POP.C3FE.2EBD2E.2FH2.FA4DE",
    ".9BA.3B2DE.CA4E2BE.2ECDFE.EHDFBEPO.CFL2E2.KOMEBC.F2C.CD3C.BEB2.2FHA3HE",
    ".10BE.2BDHBC.DA3.CBE.4B.2FHDB3CM.2EFCFEFC.MGPB2.6EDB.2BF.6H2A3C",
    ".14BDABC.2DHDF.EBC.5EA2D2AEPM.2D.LNLC.2CGPFAHF.4EDB.2BDE.5HFEA3C",
    ".10F2.2BDAHB.3BDBF.FC.5DA2DADJGC.FLBA.L2FC.JM.BADF2.2CFB2.CDHC.4HF.2DAC",
    ".9FE.2B3HA2B.2BDBF.FC.2CFDA2DADEJ2.3HCAL3E.3P2FA2B2F.3FB.CDHD.4HF.2CAC",
    ".9DE.2ABCDA3DC2FBF.E.3FBA3HAFCM.2CBC.C3.2EC.CKCDAD3E.2FE.BDAD.3EHF.3AC",
    ".9BE2BAB.EA3HDF.F2.3CB2DH2A2F.P2.EBDC2F2E.CBEC.K2FA2DAHBC.2FBDAF.3BAE.2CAE",
    ".10BDA2B.3BAHDBCF2.3ED2ABDAH.2C.F2BH.CF2BF.B2F.POCDADA2DB.2B2DF.2CBHB.2EBAC",
    ".10EDHADE.3ED3CF2.2BH2DBDAD.2MKEDA2EFD4AEFAHB.J2CADBA3DE.CBC.DA2F.3BHD",
    ".11EDA2D.3EBD2E.3BDADB2A2H.COC.EA2.BA2D2AD.HDC.PG.EA2BA3DC2BC.DA2E.2BD2B",
    ".12FDAF.E.2EDBC.2DA3DE.HAD.CJ.C.C3A3D2A2.3C2.JO.DABFH2DBE.3BDAE.2DE",
    ".13BA.CDF2B2C.2EHA3F.C.A.2OK.BF.2DA3FBA2D.CBF.2GMCBD.2EDBFC.3EABE",
    ".12EDE.FA2HFE.2EDA3.2EFCECMG.2BF.2B4.CBDB.CBF.2G2.2B.C2.B3E.2FHADEC",
    ".11CBH.CA3E.3EDHE.3ED2F.KG2.3FL2.8HL2.4G2C.3BF.3FD.2FBHA2DE2",
    ".11EB.3EAE.4DB.5ED2F.KOK.2DLI2L2A.2EL2NINL.3KM2.2B2F.5H.3EBA2FDC",
    ".11EDE2.CAH.3BDC2JP.2EDB.JO2CK.LNI3NL.CDNI4N.K2.JG.2B2F.2J2.DC.3EDB.BC",
    ".12ED2.EA2D.2BECJ3.2FDB.MGOCK.EDNLADF.K.BHLILB.K2.JGMK.B2.2J3C2.3EDB.BC",
    ".16D2AD.BF.CJ2MJ.BD.JG2OCK.4D.3CK.3E2.3K3PGOK.B2CPJ2M.2E.2EDEFC",
    ".14EB3E2.BCKJMJ2.EBE.MGM.CPK.2MFO.2K2.2KJ2K.CK3.OGOC2BC.J2MJ.F.CFE2B",
    ".19C.E.JO2MJ.CFCM2GM.PJ2.2CJK.2K2.3P2.2KJ2P.OGO2CEC.JMG2.3F2C",
    ".17FBDC.2MG3K.C.2OG2M.J3.2EQC.2K2.3PB.2KJ3.G4J.C2PG3",
    ".17DB2C.JG3M.CEKJG3M.J3.2FAF.2CK.2CD2C.KJ3.JOG3KEC2MG3",
    ".17HB.2KMO3C.CEJMG3M.PJ2.2FAB.2K2.2ED2C.CJ3.2MG3MEC.2OG2K",
    ".17FDC.JM.5CJMG4OJ.C2.2FA2.6EADC.7MG3OMK.2K2M2",
    ".18E.2KJ.5KMCMG2OM2.6HA.6EAF.8JMO3MP.4OK",
    ".22PJ.3PJK.CO2M3J.5F2.6CFC.7CJM2P.KMP.2JK",
    ".23J.10JM2J.3CB4C.3EB4.5KM2J.8K",
    ".36KJ.3CDA3C.3BHADB.5KMJP",
    ".37C.3CBA3E.3BA2DF.5KP",
    "",
    ".42C4.5C4",
    "",
    "",
    "",
    "",
    "",
    "",
]


# ---------------------------------------------------------------------------
# Base bitmap
# ---------------------------------------------------------------------------
def decode_base() -> Image.Image:
    """BASE_RLE -> the 96x96 idle frame."""
    pal = BASE_PAL + list(EXTRA.values())
    img = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    px = img.load()
    for y, rle in enumerate(BASE_RLE):
        x = 0
        i = 0
        while i < len(rle):
            ch = rle[i]
            i += 1
            n = ""
            while i < len(rle) and rle[i].isdigit():
                n += rle[i]
                i += 1
            run = int(n) if n else 1
            if ch != ".":
                idx = SYMS.index(ch)
                for k in range(run):
                    px[x + k, y] = pal[idx]
            x += run
    return img


def blit(dst, src, ox=0, oy=0) -> None:
    """alpha_composite src over dst at (ox, oy)."""
    dst.alpha_composite(src, (ox, oy))


def shift_strip(img, x0, y0, x1, y1, dx=0, dy=0, clear=True) -> None:
    """Cut img[x0:x1, y0:y1], move it by (dx, dy), paste it back."""
    strip = img.crop((x0, y0, x1, y1))
    if clear:
        blank = Image.new("RGBA", strip.size, (0, 0, 0, 0))
        img.paste(blank, (x0, y0))
    blit(img, strip, x0 + dx, y0 + dy)


# ---------------------------------------------------------------------------
# Named tones (looked up by value, never by position - positions move if
# the palette is ever re-quantised).
# ---------------------------------------------------------------------------
def _pal(v):
    for c in BASE_PAL:
        if c[:3] == v:
            return c
    raise SystemExit("tone %r missing from BASE_PAL" % (v,))


OUTLINE = _pal((8, 5, 8))          # near-black silhouette outline
SKIN = _pal((233, 197, 204))       # pale skin
SKIN_SHA = _pal((166, 128, 142))   # skin shadow / closed lid
SLEEVE = _pal((27, 18, 29))        # dark dress cloth
SLEEVE_HI = _pal((42, 28, 45))     # lit edge of the dress
CRIMSON_DEEP = _pal((38, 8, 20))   # deep crimson droplets
IRIS_TONES = {(99, 15, 41), (87, 13, 36), (73, 10, 31)}

# eye boxes in frame coordinates: lash line + crimson iris
EYE_L = (37, 38, 46, 47)
EYE_R = (51, 38, 60, 47)


# ---------------------------------------------------------------------------
# Cast reads
# ---------------------------------------------------------------------------
def blood_bead(img, cx, cy, r) -> None:
    """A bead of blood magic held between her cupped hands."""
    d = ImageDraw.Draw(img)
    d.ellipse([cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1], fill=OUTLINE)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=EXTRA["blood"])
    d.ellipse([cx - 2, cy - r + 1, cx, cy], fill=EXTRA["blood_hi"])
    img.putpixel((cx - 1, cy - r + 1), EXTRA["white"])


def droplet(img, x, y, size=2, bright=False) -> None:
    col = EXTRA["blood"] if bright else CRIMSON_DEEP
    for dy in range(size):
        for dx in range(size):
            img.putpixel((x + dx, y + dy), col)


def thrust_arm(img) -> None:
    """Cast release: the folded hands leave, a sleeve-clad arm thrusts out
    to the right and a fan of droplets scatters beyond the hand."""
    # 1. the corset shows where the folded hands were
    patch = Image.new("RGBA", (10, 7), (0, 0, 0, 0))
    for y in range(7):
        for x in range(10):
            patch.putpixel((x, y), SLEEVE if (x + y) % 3 else SLEEVE_HI)
    blit(img, patch, 43, 54)

    # 2. the arm: dark outline block, sleeve inside, lit top edge
    ox0, ox1, oy0, oy1 = 58, 81, 57, 65
    for y in range(oy0, oy1):
        for x in range(ox0, ox1):
            img.putpixel((x, y), OUTLINE)
    for y in range(oy0 + 1, oy1 - 1):
        for x in range(ox0, ox1 - 1):
            img.putpixel((x, y), SLEEVE)
    for x in range(ox0, ox1 - 1):
        img.putpixel((x, oy0 + 1), SLEEVE_HI)
    # the pale hand at the end of the sleeve
    for y in range(oy0 + 1, oy1 - 1):
        for x in range(76, 80):
            img.putpixel((x, y), SKIN)
    img.putpixel((77, oy0 + 1), SKIN_SHA)

    # 3. the droplet fan beyond the hand
    droplet(img, 83, 56)
    droplet(img, 85, 62)
    droplet(img, 88, 58, bright=True)
    droplet(img, 86, 52, bright=True)


# ---------------------------------------------------------------------------
# The six frames
# ---------------------------------------------------------------------------
def frame_idle() -> Image.Image:
    return decode_base()

def frame_walk(which: str) -> Image.Image:
    img = decode_base()
    # 1 px bob on the whole figure
    img.paste(img.crop((0, 1, FRAME, FRAME)), (0, 0))
    img.paste(Image.new("RGBA", (FRAME, 1), (0, 0, 0, 0)), (0, FRAME - 1))
    if which == "A":
        shift_strip(img, 48, 76, 60, 94, 0, -3)   # right leg steps up
    else:
        shift_strip(img, 37, 76, 48, 94, 0, -3)   # left leg steps up
    return img

def frame_cast(windup: bool) -> Image.Image:
    img = decode_base()
    if windup:
        _blaze_eyes(img)
        blood_bead(img, 48, 61, 4)
    else:
        thrust_arm(img)
    return img

def frame_blink() -> Image.Image:
    img = decode_base()
    _shut_eyes(img)
    return img


def _blaze_eyes(img) -> None:
    """Bright crimson irises for the cast wind-up."""
    for (x0, y0, x1, y1) in (EYE_L, EYE_R):
        for y in range(y0, y1):
            for x in range(x0, x1):
                r, g, b, a_ = img.getpixel((x, y))
                if a_ and (r, g, b) in IRIS_TONES:
                    img.putpixel((x, y), EXTRA["iris_hi"])


def _shut_eyes(img) -> None:
    """The idle blink: irises become skin, a warm shadow closes the lid."""
    for (x0, y0, x1, y1) in (EYE_L, EYE_R):
        lid_row = None
        for y in range(y0, y1):
            for x in range(x0, x1):
                r, g, b, a_ = img.getpixel((x, y))
                if a_ and (r, g, b) in IRIS_TONES:
                    img.putpixel((x, y), (0, 0, 0, 0))
                    if lid_row is None:
                        lid_row = y
        if lid_row is not None:
            for x in range(x0, x1):
                r, g, b, a_ = img.getpixel((x, lid_row))
                if a_:
                    img.putpixel((x, lid_row), SKIN_SHA)


def build_sheet() -> Image.Image:
    frames = [
        frame_idle(),
        frame_walk("A"),
        frame_walk("B"),
        frame_cast(True),
        frame_cast(False),
        frame_blink(),
    ]
    sheet = Image.new("RGBA", (FRAME * FRAMES, FRAME), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.alpha_composite(f, (i * FRAME, 0))
    return sheet


def build_preview(sheet: Image.Image) -> Image.Image:
    zoom, pad = 4, 16
    labels = ["idle", "walk A", "walk B", "cast A", "cast B", "idle blink"]
    w = pad + FRAMES * (FRAME * zoom + pad)
    h = 34 + FRAME * zoom + pad + 18
    img = Image.new("RGBA", (w, h), (22, 18, 26, 255))
    d = ImageDraw.Draw(img)
    d.text((pad, 10), "VELMIRA - 6 frames, 96x96 (the player's reference, full res)",
           fill=(238, 216, 226, 255))
    for i in range(FRAMES):
        x = pad + i * (FRAME * zoom + pad)
        frame = sheet.crop((i * FRAME, 0, (i + 1) * FRAME, FRAME))
        img.alpha_composite(frame.resize((FRAME * zoom, FRAME * zoom), Image.NEAREST),
                            (x, 34))
        d.text((x, h - 14), labels[i], fill=(200, 168, 186, 255))
    return img


def main() -> None:
    sheet = build_sheet()
    sheet.save("assets/textures/player_shabnam.png")
    print("wrote assets/textures/player_shabnam.png", sheet.size,
          "-> %d frames of %d" % (FRAMES, FRAME))
    build_preview(sheet).save("docs/images/velmira_preview.png")
    print("wrote docs/images/velmira_preview.png")


if __name__ == "__main__":
    main()
