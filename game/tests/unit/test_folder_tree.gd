extends GutTest
## Ports the Story 1.1 folder-tree check (AC2 of Story 1.1).

const REQUIRED_DIRS: Array[String] = [
	"res://src/core",
	"res://src/autoloads",
	"res://src/main",
	"res://data/actions",
	"res://data/bits",
	"res://data/bosses",
	"res://data/combos",
	"res://data/config",
	"res://data/duck",
	"res://data/player",
	"res://data/text",
	"res://assets/fonts",
	"res://assets/audio/music",
	"res://assets/audio/sfx",
	"res://assets/shaders",
	"res://tests/unit",
	"res://tests/integration",
	"res://tests/replays",
	"res://tools",
	"res://addons",
]


func test_required_folders_exist() -> void:
	for path: String in REQUIRED_DIRS:
		assert_true(DirAccess.dir_exists_absolute(path), "missing folder %s" % path)
