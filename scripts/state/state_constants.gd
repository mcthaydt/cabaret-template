@icon("res://resources/editor_icons/utility.svg")
extends RefCounted
class_name StateConstants

## Action Types
# Special action dispatched during initialization to trigger reducers to return initial state
const INIT_ACTION := StringName("@@INIT")

## Scene Tree Groups
# Group name used by M_StateManager for scene tree discovery
const STATE_STORE_GROUP := "state_store"

## Persistence Keys
# Keys used in save file structure by U_StatePersistence
const SAVE_VERSION_KEY := "version"
const SAVE_CHECKSUM_KEY := "checksum"
const SAVE_DATA_KEY := "data"
