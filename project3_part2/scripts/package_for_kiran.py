#!/usr/bin/env python3
"""Package the existing SOF and the reference board's measured challenge list.

This does not compile RTL, program hardware, or modify the source workbook.
Only challenge inputs are shared; reference responses are not copied.
"""

import csv
import hashlib
import io
import json
import re
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET


ROOT = Path(__file__).resolve().parents[2]
PART2 = ROOT / "project3_part2"
OUTPUT = ROOT / "for_kiran.zip"
SOF = PART2 / "quartus/output_files/Project3.sof"
WORKBOOK = PART2 / "tb/ro_puf_256_crps.xlsx"
REPEATS = 5
NAMESPACE = {"s": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def read_measured_challenges():
    """Read challenge columns without copying any reference response values."""
    with zipfile.ZipFile(WORKBOOK) as workbook:
        strings = []
        if "xl/sharedStrings.xml" in workbook.namelist():
            tree = ET.fromstring(workbook.read("xl/sharedStrings.xml"))
            strings = ["".join(entry.itertext()) for entry in tree]

        def cell_value(cell):
            if cell.attrib.get("t") == "inlineStr":
                return "".join(cell.find("s:is", NAMESPACE).itertext())
            value = cell.find("s:v", NAMESPACE)
            if value is None:
                return ""
            return strings[int(value.text)] if cell.attrib.get("t") == "s" else value.text

        sheet = ET.fromstring(workbook.read("xl/worksheets/sheet1.xml"))
        rows = sheet.findall("s:sheetData/s:row", NAMESPACE)
        header = {re.sub(r"[0-9]", "", c.attrib["r"]): cell_value(c) for c in rows[0]}
        if [header.get(c) for c in "ABCD"] != [
            "Cha1", "Cha0", "Challenge (combined)", "Response"
        ]:
            raise RuntimeError("Workbook headers changed; review the challenge extraction.")

        challenges = []
        for row in rows[1:]:
            cells = {re.sub(r"[0-9]", "", c.attrib["r"]): cell_value(c) for c in row}
            if not cells.get("D", "").strip():
                continue
            cha1, cha0, combined = (cells.get(c, "") for c in "ABC")
            if not all(re.fullmatch(r"[01]{4}", value) for value in (cha1, cha0)):
                raise RuntimeError("Measured row has a malformed challenge.")
            if combined != cha1 + cha0 or cha0 == cha1:
                raise RuntimeError("Review combined challenge ordering or a same-RO challenge.")
            challenges.append((cha1, cha0))
    if len(challenges) < 16 or len(set(challenges)) != len(challenges):
        raise RuntimeError("Need at least 16 distinct recorded reference challenges.")
    return challenges


def csv_bytes(headers, rows):
    stream = io.StringIO(newline="")
    writer = csv.writer(stream)
    writer.writerow(headers)
    writer.writerows(rows)
    return stream.getvalue().encode("utf-8")


def instructions(challenges, bitstream_hash):
    settings = "\n".join(
        f"C{i:02d}     {cha1}       {cha0}       {cha1 + cha0}"
        for i, (cha1, cha0) in enumerate(challenges, 1)
    )
    return f"""RO PUF: PROGRAMMING AND CRP COLLECTION FOR KIRAN
================================================

START HERE
----------
Use the SAME Cyclone V GX board model/pinout as the reference board, with
FPGA part 5CGXFC5C6F27C7. Check the board/chip identification before loading.
Matching the Cyclone V family alone is insufficient: the pinout must match.

Required software: Quartus Prime Programmer (included in the full Quartus
installation or available as a standalone Programmer installation).
The supplied design was compiled with Quartus Prime Lite 21.1.

Project3.sof is the complete, already compiled FPGA configuration. You do
not need the HDL files, QPF, QSF, placement Tcl, or another synthesis run.
Use this exact SOF on the second device to preserve the implementation.
JTAG loading is temporary; reload this SOF after the board loses power.

Project3.sof SHA-256:
{bitstream_hash}

1. CONNECT THE BOARD
--------------------
1) Extract the entire ZIP into an ordinary folder on your computer.
2) Power the board and connect its USB-Blaster/JTAG programming USB port.
3) If Quartus runs in a virtual machine, pass the USB-Blaster device through
   to that VM (VirtualBox: Devices > USB > select the actual USB-Blaster).
4) Open Quartus. Select Tools > Programmer. No Quartus project is required.

2. LOAD THE SUPPLIED BITSTREAM
------------------------------
1) Click Hardware Setup. Select the local USB-Blaster or USB-Blaster II
   corresponding to the connected board, then close Hardware Setup.
2) Set the programming mode to JTAG.
3) Click Auto Detect if the device chain is not already displayed. Confirm
   that the detected FPGA corresponds to the specified target device.
4) Select the FPGA row and attach Project3.sof using Change File. If the
   chain is empty, Add File can add Project3.sof directly. Associate the
   SOF with the FPGA row; avoid duplicate FPGA rows in the displayed chain.
5) Tick Program/Configure for that FPGA row.
6) Click Start. Wait for Progress = 100% (Successful).
7) Press and hold KEY0. The response, completion, and invalid LEDs should
   clear while reset is held.

An optional Project3.cdf is included with a relative SOF path. It describes
the original single-FPGA JTAG chain. The Add File/Auto Detect procedure above
is the preferred method because it checks your connected hardware. If you
open the CDF and Quartus cannot locate the SOF, browse to the included file.

3. SWITCH AND LED MAPPING
-------------------------
KEY0 pressed/held: reset asserted, ROs disabled, counters cleared.
KEY0 released: reset deasserted, ROs enabled, counting begins.

Cha1 = SW7 SW6 SW5 SW4, written most significant bit first.
Cha0 = SW3 SW2 SW1 SW0, written most significant bit first.
Combined challenge = Cha1 followed by Cha0 = SW7 ... SW0.
Keep SW8 and SW9 at 0; they are unused by the PUF.

Response = LEDG3 LEDG2 LEDG1 LEDG0, in that exact order.
Done = LEDG4. Read the result only after this green LED is on and settled.
Invalid = LEDR3 LEDR2 LEDR1 LEDR0, in that exact order.
A lit LED represents 1; an unlit LED represents 0.
LEDG4 is NOT part of the four-bit response.

Example of switch interpretation only:
Cha1=0010 and Cha0=0101 means SW7...SW0=00100101.

4. MEASURE THE SAME CHALLENGES AS THE REFERENCE BOARD
----------------------------------------------------
The following {len(challenges)} pairs were extracted from rows that already contain a
response in the reference workbook ro_puf_256_crps.xlsx. They are the real
recorded challenge inputs, not the older proposed hardware template.
Reference response values have intentionally not been included.

ID      Cha1       Cha0       SW7...SW0
{settings}

For EACH challenge:
1) Press and HOLD KEY0.
2) Set SW7...SW0 to the eight-bit value in challenge_settings.csv.
3) Release KEY0. Keep all switches unchanged until the result is recorded.
4) Wait for LEDG4 (Done) to become 1 and for the LED pattern to settle.
5) Record LEDG3...LEDG0 as four digits, including leading zeros.
6) Record LEDR3...LEDR0 as four digits, including 0000 when all are off.
7) Record Done as 1 for a completed measurement.
8) Reset and perform {REPEATS} independent measurements of this SAME challenge,
   using repeats 1 through {REPEATS} in kiran_crps.csv. Every repeat needs a fresh
   KEY0 press/release; rereading the same latched result is not a repeat.
9) Proceed to the next challenge after its {REPEATS} measurements are recorded.

There are {len(challenges) * REPEATS} blank measurement rows in kiran_crps.csv. Device ID is KIRAN.
The combined eight-bit switch setting is repeated on every row for clarity.
Fill only response_bin, invalid_bin, done, and optional notes.

The CSV uses the existing hardware analyzer's field names. In that CSV,
cha0_bin precedes cha1_bin; the separately labeled challenge_sw7_to_sw0
column always gives the physical SW7...SW0 order.

Keep all responses and invalid flags exactly as observed. If any red flag
is on, preserve that attempt and mark a note; it is excluded from valid HD
comparisons. If Done never becomes 1, record done=0 and describe the issue.
Do not silently replace a challenge on just one device. Any replacement
must be measured on BOTH boards and kept separately from the original set.

If editing with Excel, import the CSV using Data > From Text/CSV and set
the challenge/response/invalid columns to Text so leading zeros survive.
A plain text editor or other CSV editor also works. Return CSV, not a
screenshot alone, so each challenge and repeat can be matched exactly.

5. WHAT TO SEND BACK
--------------------
Send the completed kiran_crps.csv. Also include:
- Board model and FPGA part number in the notes for the first record.
- Room/board conditions if unusual, and any invalid or changing responses.
- A screenshot showing 100% (Successful) in Quartus Programmer, if possible.

The comparison will match the SAME Cha1/Cha0 pair across the two boards.
For each four-bit response pair, HD = popcount(response_A XOR response_B).
Normalized inter-device HD = 100 * sum(HD) / (4 * number_of_common_valid_pairs).
The unbiased-response benchmark is 50%; identical responses are NOT required
on different devices. Repeats separately check whether each device is stable.

The reference workbook's invalid LED states were not recorded. Before
claiming a valid two-device result, the reference-board operator must also
confirm Done=1 and Invalid=0000 for these same challenges. No reference
status values or individual raw repeat records have been invented here.

6. USB-BLASTER TROUBLESHOOTING
-----------------------------
If Hardware Setup lists only an Ethernet/remote server entry, the local
USB-Blaster has not been detected. Check board power, the programming USB
port/cable, and VM USB passthrough. Use the actual local hardware entry.

On Linux, diagnostic commands from a Quartus-enabled terminal are:
    quartus_pgm -l
    jtagconfig

If the USB-Blaster is visible to Linux but inaccessible to Quartus, the
original Linux udev rules are included at linux/51-usbblaster.rules.
Only when needed, from this extracted folder, install them using:
    sudo cp linux/51-usbblaster.rules /etc/udev/rules.d/51-usbblaster.rules
    sudo chown root:root /etc/udev/rules.d/51-usbblaster.rules
    sudo udevadm control --reload-rules
Then disconnect/reconnect the programming USB cable and reopen Programmer.
These rules are for Linux; Windows uses the USB-Blaster driver installed
with Quartus. VM USB ownership and OS driver permissions are separate issues.

If programming fails after detecting hardware, confirm that Project3.sof
is assigned to the correct detected FPGA, Program/Configure is ticked, and
JTAG mode is selected. Retain the exact Quartus error if it still fails.

7. FILES IN THIS PACKAGE
------------------------
Project3.sof                 Already compiled FPGA configuration (required).
Project3.cdf                 Optional portable Programmer chain setup.
README_FIRST.txt             These programming and measurement instructions.
challenge_settings.csv       Exact measured-reference challenges and switches.
kiran_crps.csv               Blank {REPEATS}-repeat measurement sheet for KIRAN.
linux/51-usbblaster.rules     Original Linux USB-Blaster permission rules.
MANIFEST.json                Target, hashes, and challenge-set provenance.
SHA256SUMS.txt                File integrity checks; optional on Linux:
                                 sha256sum -c SHA256SUMS.txt
"""


def main():
    if OUTPUT.exists():
        raise FileExistsError(f"Preserving existing package: {OUTPUT}")
    bitstream = SOF.read_bytes()
    build = json.loads((SOF.parent / "build_status.json").read_text())
    bitstream_hash = sha256(bitstream)
    if not build.get("build_passed") or bitstream_hash != build["bitstream_sha256"]:
        raise RuntimeError("SOF does not match the saved successful build.")
    challenges = read_measured_challenges()

    cdf = (SOF.parent / "Project3.cdf").read_text()
    cdf, replacements = re.subn(r'Path\("[^"]*"\)', 'Path("./")', cdf)
    if replacements != 1 or 'File("Project3.sof")' not in cdf:
        raise RuntimeError("Review the Programmer chain file before packaging.")

    files = {
        "Project3.sof": bitstream,
        "Project3.cdf": cdf.encode("utf-8"),
        "README_FIRST.txt": instructions(challenges, bitstream_hash).encode("utf-8"),
        "challenge_settings.csv": csv_bytes(
            ["challenge_id", "cha1_sw7_to_sw4", "cha0_sw3_to_sw0", "switches_sw7_to_sw0"],
            [[f"C{i:02d}", cha1, cha0, cha1 + cha0]
             for i, (cha1, cha0) in enumerate(challenges, 1)],
        ),
        "kiran_crps.csv": csv_bytes(
            ["device_id", "challenge_id", "cha0_bin", "cha1_bin", "challenge_sw7_to_sw0",
             "repeat", "response_bin", "invalid_bin", "done", "notes"],
            [["KIRAN", f"C{i:02d}", cha0, cha1, cha1 + cha0, repeat, "", "", "", ""]
             for i, (cha1, cha0) in enumerate(challenges, 1)
             for repeat in range(1, REPEATS + 1)],
        ),
        "linux/51-usbblaster.rules": (ROOT / "setup/51-usbblaster.rules").read_bytes(),
    }
    manifest = {
        "target_device": "5CGXFC5C6F27C7",
        "board_requirement": "Same Cyclone V GX board model and pinout as the reference board",
        "quartus_build_version": "21.1.0 Build 842 Lite Edition",
        "bitstream_sha256": bitstream_hash,
        "challenge_source": "project3_part2/tb/ro_puf_256_crps.xlsx, CRPs sheet, rows with a recorded response",
        "challenge_source_sha256": sha256(WORKBOOK.read_bytes()),
        "challenge_order": "Source workbook row order; combined challenge = Cha1 || Cha0",
        "challenge_count": len(challenges),
        "repeats_per_challenge": REPEATS,
        "blank_measurement_rows": len(challenges) * REPEATS,
        "reference_responses_included": False,
        "reference_status_note": "Invalid flags are unrecorded in the reference workbook; confirm on hardware before valid-HD claims",
        "files_sha256": {name: sha256(data) for name, data in files.items()},
    }
    files["MANIFEST.json"] = (json.dumps(manifest, indent=4) + "\n").encode("utf-8")
    files["SHA256SUMS.txt"] = "".join(
        f"{sha256(data)}  {name}\n" for name, data in sorted(files.items())
    ).encode("utf-8")

    with zipfile.ZipFile(OUTPUT, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in sorted(files.items()):
            archive.writestr(f"for_kiran/{name}", data)

    # Validate the actual delivery file, including the blank measurement rows.
    with zipfile.ZipFile(OUTPUT) as archive:
        if archive.testzip() is not None:
            raise RuntimeError("ZIP integrity check failed.")
        for name, original in files.items():
            if archive.read(f"for_kiran/{name}") != original:
                raise RuntimeError(f"Archive content mismatch: {name}")
        records = list(csv.DictReader(io.StringIO(
            archive.read("for_kiran/kiran_crps.csv").decode("utf-8")
        )))
        assert len(records) == len(challenges) * REPEATS
        assert {(r["cha1_bin"], r["cha0_bin"]) for r in records} == set(challenges)
        assert all(not r[key] for r in records for key in ["response_bin", "invalid_bin", "done"])
        assert all(r["challenge_sw7_to_sw0"] == r["cha1_bin"] + r["cha0_bin"] for r in records)
        assert "/home/" not in archive.read("for_kiran/Project3.cdf").decode("utf-8")
        assert sha256(archive.read("for_kiran/Project3.sof")) == bitstream_hash
    print(f"Created {OUTPUT}")
    print(f"Verified {len(files)} files; exact SOF hash; {len(challenges)} reference challenges; {len(records)} blank measurements.")
    print(f"ZIP bytes: {OUTPUT.stat().st_size}")


if __name__ == "__main__":
    main()
