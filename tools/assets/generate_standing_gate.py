"""Export the reviewed gate with two colliders and faction-painted carvings."""

import argparse
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent / "examples"))
from generate_examples import export_building, stone_gate


def gate(index, materials):
    return stone_gate(index, {**materials, "mark": materials["trim"]})


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", required=True, type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    export_building(args.out_dir / "buildings", "standing_stone_gate_stages", gate,
                    [(-1.25, (1.04, 1.05, 2.51)), (1.25, (1.04, 1.05, 2.51))], production=True)
