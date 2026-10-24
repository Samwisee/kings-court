"""Turns `flutter test --reporter expanded` output into GitHub annotations,
so failures can be read from the API without downloading the logs."""
import sys

lines = open(sys.argv[1], encoding="utf-8", errors="replace").read().splitlines()
out = []
i = 0
while i < len(lines) and len(out) < 25:
    line = lines[i]
    if line.startswith("══╡ EXCEPTION CAUGHT BY") and "WIDGET INSPECTOR" not in line:
        block = [line]
        i += 1
        while i < len(lines) and not lines[i].startswith("═════") and len(block) < 45:
            block.append(lines[i])
            i += 1
        # Find the test this belongs to further down.
        for j in range(i, min(i + 400, len(lines))):
            if lines[j].endswith("[E]"):
                block.insert(0, "TEST " + lines[j].split(": ", 1)[-1])
                break
        out.append(block)
    elif "Compilation failed" in line or line.strip().startswith("Expected:"):
        out.append(lines[max(0, i - 3): i + 12])
    i += 1
for block in out:
    text = "%0A".join(l.replace("%", "%25") for l in block)[:6000]
    print("::error::" + text)
# The last lines show which test was running if the run timed out.
import re
progress = [l for l in lines if re.match(r"^\d\d:\d\d \+\d+", l)]
tail = progress[-3:] + [l for l in lines if l.strip()][-3:]
print("::warning::LAST " + "%0A".join(l.replace("%", "%25") for l in tail)[:3000])
