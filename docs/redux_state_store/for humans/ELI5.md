# Redux State Store - Explain Like I'm 5

**Purpose**: A simple, friendly guide to understanding how our state management system works.

**Last Updated**: 2025-10-19 *(Added schema validation)*

---

## What Is It? (The Simple Version)

Imagine your game is like a big house with many rooms. Each room (system) needs to know things like:

- What's the player's score?
- Is the menu open?
- What level are we on?

Instead of having each room keep its own notepad (which gets messy when everyone has different notes), we have **one special notebook** that everyone shares. This notebook is called the **State Store**.

**The Redux State Store is a shared notebook that keeps track of everything important in your game, and makes sure everyone gets the same information.**

---

## The Big Picture

```
Your Game
├─ M_StateManager ← The Special Notebook (holds all game info)
├─ Movement System ← Reads from notebook: "What's the player's speed?"
├─ Jump System ← Reads from notebook: "Can the player jump?"
├─ UI System ← Reads from notebook: "What's the score?"
└─ Save System ← Saves the notebook to disk
```

Every part of your game can:

- **Read** from the notebook (get information)
- **Write** to the notebook (update information)
- **Listen** for changes (get notified when something updates)

---

## The Key Players

### 1. M_StateManager - The Notebook Keeper

Think of this as the librarian who manages the shared notebook.

**What it does:**

- Keeps the notebook safe
- Makes sure only one person writes at a time
- Tells everyone when something changes
- Remembers the history (for time-travel debugging)

**Where it lives:** `scripts/managers/m_state_manager.gd`

**How to find it:**

```gdscript
# From anywhere in your game
var store = U_StateStoreUtils.get_store(self)
# Now you can read/write to the notebook!
```

### 2. Actions - Request Forms

Actions are like **filling out a form** to make a change.

Instead of scribbling directly in the notebook (which could cause mistakes), you fill out a form that says:

- "What do you want to change?" (the action type)
- "What's the new value?" (the payload)

**Example:**

```gdscript
# Bad way (direct scribbling):
notebook.score = 100  # This doesn't exist!

# Good way (fill out a form):
var action = {
 "type": "game/set_score",
 "payload": 100
}
store.dispatch(action)
```

**Helper functions make this easier:**

```gdscript
# Even easier with action creators
var action = U_ActionUtils.create_action("game/set_score", 100)
store.dispatch(action)
```

### 3. Reducers - The Rule Book

Reducers are like **instruction manuals** that say "When you get this form, here's what to do."

Each reducer manages one section of the notebook:

- `GameReducer` manages game stuff (score, level, unlocks)
- `UiReducer` manages UI stuff (menus, settings)
- `SessionReducer` manages session stuff (player preferences)

**Example reducer:**

```gdscript
# This is like an instruction that says:
# "When someone asks to add score, add the payload to current score"

static func reduce(current_state: Dictionary, action: Dictionary) -> Dictionary:
 match action["type"]:
  "game/add_score":
   var new_state = current_state.duplicate(true)
   new_state["score"] += action["payload"]
   return new_state
  _:
   return current_state  # No change
```

### 4. State - The Notebook Contents

The state is the actual information in the notebook, organized in sections:

```gdscript
{
 "game": {
  "score": 100,
  "level": 1,
  "unlocks": ["double_jump", "dash"]
 },
 "ui": {
  "active_menu": "pause_menu",
  "settings": {"volume": 0.8}
 },
 "session": {
  "player_name": "Alex",
  "save_slot": 1
 }
}
```

### 5. Selectors - Quick Lookups

Selectors are like **bookmarks** that help you find information quickly.

**Simple lookup:**

```gdscript
var score = store.select("game.score")  # Returns 100
```

**Smart lookup (with memory):**

```gdscript
# This remembers the answer if nothing changed
var score_selector = MemoizedSelector.new(
 func(state): return state["game"]["score"]
)

var score = store.select(score_selector)  # Calculates once
var score_again = store.select(score_selector)  # Uses cached answer!
```

### 6. Schemas - The Quality Checklist

Schemas are like **quality checklists** that make sure everything is correct.

Think of it like this: When you fill out a form at school, there are rules:

- Name must be text (not a number)
- Age must be a number (not "banana")
- Grade must be between 1 and 12

Schemas do the same thing for your state! They check:

- Is the score a number? (not text)
- Is the score positive? (not negative)
- Are all the required fields there?

**Example schema:**

```gdscript
static func get_schema() -> Dictionary:
 return {
  "type": "object",
  "properties": {
   "score": {"type": "int", "minimum": 0},  # Score must be a positive number
   "name": {"type": "string"},  # Name must be text
   "level": {"type": "int", "minimum": 1}  # Level must be 1 or higher
  },
  "required": ["score", "name", "level"]  # All three are required
 }
```

**When do you add schemas?**
After you have 3-5 reducers working well. Think of it like adding spell-check after you've written a few chapters - it helps catch mistakes before your game gets too complex!

**Do you have to use schemas?**
No! They're optional. But they're really helpful for catching bugs early, especially if you're working with other developers.

---

## How It Works (Step By Step)

Let's follow what happens when the player collects a coin worth 10 points:

### Step 1: Something Happens

```gdscript
# In your coin collection code
func _on_coin_collected():
 var store = U_StateStoreUtils.get_store(self)
 store.dispatch(U_ActionUtils.create_action("game/add_score", 10))
```

### Step 2: The Action Goes to the Notebook Keeper

The M_StateManager receives your request form.

### Step 3: The Notebook Keeper Checks the Rule Book

```gdscript
# M_StateManager internally does this:
# 1. Make a copy of the notebook (so we don't mess up the original)
var new_state = _state.duplicate(true)

# 2. Ask each reducer "Do you handle this?"
for reducer in _reducers:
 new_state = reducer.reduce(new_state, action)
```

### Step 4: The Reducer Updates the Copy

```gdscript
# GameReducer says: "I handle game/add_score!"
match action["type"]:
 "game/add_score":
  var new_state = current_state.duplicate(true)
  new_state["score"] = 90 + 10  # Was 90, now 100
  return new_state
```

### Step 5: The Notebook Keeper Saves the New Version

```gdscript
# M_StateManager replaces the old notebook with the new one
_state = new_state
_state_version += 1  # Keep track of which version we're on
```

### Step 6: Everyone Gets Notified

```gdscript
# M_StateManager tells everyone who's listening
state_changed.emit(_state)
action_dispatched.emit(action)
```

### Step 7: UI Updates

```gdscript
# In your HUD system that subscribed to changes
func _on_state_changed(new_state):
 score_label.text = str(new_state["game"]["score"])
 # Score now shows "100"!
```

**Visual Flow:**

```
Player collects coin
         │
         ▼
Create action: "game/add_score" with payload 10
         │
         ▼
M_StateManager receives action
         │
         ▼
Make copy of state
         │
         ▼
GameReducer adds 10 to score (90 → 100)
         │
         ▼
Save new state, increment version
         │
         ▼
Notify all subscribers
         │
         ▼
HUD updates to show "Score: 100"
```

---

## Why We Use It (The Benefits)

### 1. Everyone Gets the Same Answer

**Without the notebook:**

```
System A thinks score is 90
System B thinks score is 100
System C doesn't know the score
→ Chaos!
```

**With the notebook:**

```
Everyone asks the notebook → Everyone gets 100 → Peace!
```

### 2. You Can See What Happened

The notebook keeper remembers every change:

```
Action 1: "game/add_score" (10 points)
Action 2: "game/add_score" (5 points)
Action 3: "game/level_up"
```

This is AMAZING for debugging! You can see exactly what happened.

### 3. Time-Travel Debugging

Because we remember all the changes, you can:

- Step backward through history
- See what the state was at any point
- Replay bugs to understand what went wrong

```gdscript
store.enable_time_travel(true)
# Play your game, bug happens...
# Now you can step backward and see what led to the bug!
```

### 4. Easy Saving and Loading

The notebook is already organized, so saving is simple:

```gdscript
# Save persistable slices (e.g., game + session)
var err = store.save_state("user://savegame.json")

# Or only save selected slices
var err2 = store.save_state("user://savegame.json", [StringName("game"), StringName("session")])

# Load it back later (rehydrates store state)
var err3 = store.load_state("user://savegame.json")
```

### 5. Systems Don't Need to Know About Each Other

**Without the notebook (tight coupling):**

```gdscript
# Movement system needs direct reference to UI system
movement_system.ui_system.update_score(100)
# This creates a tangled mess!
```

**With the notebook (loose coupling):**

```gdscript
# Movement system just updates the notebook
store.dispatch(U_ActionUtils.create_action("game/add_score", 100))

# UI system listens for changes
store.subscribe(func(state):
 update_score_display(state["game"]["score"])
)
# Systems don't even know each other exist!
```

---

## Common Patterns (How to Actually Use It)

### Pattern 1: Reading State

**Simple read:**

```gdscript
var store = U_StateStoreUtils.get_store(self)
var current_score = store.select("game.score")
print("Score is: ", current_score)
```

**Read with memoization (for expensive calculations):**

```gdscript
# Create selector once
var is_high_score_selector = MemoizedSelector.new(
 func(state):
  return state["game"]["score"] > state["game"]["high_score"]
)

# Use it many times (only calculates when state changes)
func _process(delta):
 if store.select(is_high_score_selector):
  show_high_score_celebration()
```

### Pattern 2: Changing State

**Always use dispatch:**

```gdscript
# Get the store
var store = U_StateStoreUtils.get_store(self)

# Create an action
var action = U_ActionUtils.create_action("game/add_score", 50)

# Dispatch it
store.dispatch(action)
```

### Pattern 3: Listening for Changes

**Subscribe to all changes:**

```gdscript
func _ready():
 var store = U_StateStoreUtils.get_store(self)

 # Subscribe (save unsubscribe function for cleanup)
 _unsubscribe = store.subscribe(func(new_state):
  _on_state_changed(new_state)
 )

func _on_state_changed(state: Dictionary):
 # React to any state change
 _update_ui(state)

func _exit_tree():
 # Clean up when this node is removed
 if _unsubscribe:
  _unsubscribe.call()
```

### Pattern 4: Creating a New Reducer

**Step 1: Create the reducer file:**

```gdscript
# scripts/state/reducers/my_reducer.gd
class_name MyReducer

static func get_slice_name() -> StringName:
 return "my_slice"

static func get_initial_state() -> Dictionary:
 return {
  "value": 0,
  "items": []
 }

static func get_persistable() -> bool:
 return true  # Should this be saved to disk?

static func get_schema() -> Dictionary:
 return {
  "type": "object",
  "properties": {
   "value": {"type": "int"},
   "items": {"type": "array", "items": {"type": "string"}}
  },
  "required": ["value", "items"]
 }

static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
 match action["type"]:
  "my_slice/set_value":
   var new_state = state.duplicate(true)
   new_state["value"] = action["payload"]
   return new_state
  "my_slice/add_item":
   var new_state = state.duplicate(true)
   new_state["items"].append(action["payload"])
   return new_state
  _:
   return state  # No change
```

**Step 2: Register it:**

```gdscript
# In your setup code (usually in M_StateManager's ready or a setup script)
store.register_reducer(MyReducer)
```

**Step 3: Use it:**

```gdscript
# Dispatch actions to it
store.dispatch(U_ActionUtils.create_action("my_slice/set_value", 42))
store.dispatch(U_ActionUtils.create_action("my_slice/add_item", "sword"))

# Read from it
var my_value = store.select("my_slice.value")  # 42
var my_items = store.select("my_slice.items")  # ["sword"]
```

---

## Mental Models (Ways to Think About It)

### The Post Office Analogy

- **State Store** = The post office's sorting system
- **Actions** = Letters you send
- **Reducers** = Mail sorters who know where each letter goes
- **State** = All the mailboxes with their contents
- **Selectors** = Looking up what's in a specific mailbox
- **Subscribers** = People who get notified when they get mail

When you want to send a message (change state):

1. You write a letter (create action)
2. You drop it in the mailbox (dispatch)
3. The mail sorter (reducer) puts it in the right place
4. Everyone watching that mailbox gets notified (subscribers)

### The Recipe Book Analogy

- **State** = All the ingredients you have in your kitchen
- **Actions** = Requests like "add 2 cups of flour"
- **Reducers** = The recipe that says how to respond to each request
- **M_StateManager** = The chef who follows the recipe
- **Selectors** = Quick lookups like "how much flour do I have?"

You never change ingredients directly. You always:

1. Request a change (action)
2. Follow the recipe (reducer)
3. Get new ingredient list (new state)

### The Library Analogy

- **State Store** = The library
- **State** = All the books and their locations
- **Actions** = Request cards ("I want to check out this book")
- **Reducers** = Library rules ("Here's what to do when someone checks out a book")
- **M_StateManager** = The librarian
- **Selectors** = The card catalog (quick lookup)
- **Subscribers** = People who want to know when new books arrive

---

## The Golden Rules

### Rule 1: Never Change State Directly

**BAD:**

```gdscript
var state = store.get_state()
state["game"]["score"] = 100  # DON'T DO THIS!
```

**GOOD:**

```gdscript
store.dispatch(U_ActionUtils.create_action("game/set_score", 100))
```

**Why?** If you change it directly:

- Nobody gets notified
- History doesn't work
- Time-travel breaks
- Saves won't work properly

### Rule 2: Reducers Must Return New Objects

**BAD:**

```gdscript
static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
 state["score"] += 10  # Modifying the input!
 return state
```

**GOOD:**

```gdscript
static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
 var new_state = state.duplicate(true)  # Make a copy first
 new_state["score"] += 10
 return new_state
```

**Why?** Because:

- We need to keep the old state for history
- Changing the input causes weird bugs
- Copies ensure clean state transitions

### Rule 3: Actions Should Be Descriptive

**BAD:**

```gdscript
store.dispatch(U_ActionUtils.create_action("update", 10))
# What are we updating??
```

**GOOD:**

```gdscript
store.dispatch(U_ActionUtils.create_action("game/add_score", 10))
# Clear: we're adding 10 to the game score
```

**Why?** Because:

- You can read the history and understand what happened
- Debugging is easier
- Other developers can understand your code

### Rule 4: One M_StateManager Per Scene Tree

There should only be ONE notebook keeper in your game.

```gdscript
# The M_StateManager checks for this automatically
func _ready() -> void:
 var existing = get_tree().get_nodes_in_group("state_store")
 if existing.size() > 0:
  push_error("Multiple M_StateManager instances!")
  queue_free()  # Remove duplicate
```

---

## Quick Reference

### How to Get the Store

```gdscript
var store = U_StateStoreUtils.get_store(self)
```

### How to Read State

```gdscript
# Simple read
var score = store.select("game.score")

# With memoization
var selector = MemoizedSelector.new(func(state): return state["game"]["score"])
var score = store.select(selector)
```

### How to Change State

```gdscript
# Create and dispatch action
var action = U_ActionUtils.create_action("game/add_score", 10)
store.dispatch(action)
```

### How to Listen for Changes

```gdscript
var unsubscribe = store.subscribe(func(state):
 print("State changed!", state)
)

# Later, clean up
unsubscribe.call()
```

### How to Save/Load

```gdscript
# Save (persists reducers marked persistable)
var err = store.save_state("user://save.json")

# Optional: whitelist specific slices
var err2 = store.save_state("user://save.json", [StringName("game")])

# Load (rehydrates state and emits state_changed)
var err3 = store.load_state("user://save.json")
```

### Action Naming Convention

```
domain/action_name

Examples:
- game/add_score
- game/level_up
- ui/open_menu
- ui/close_menu
- session/save_game
```

---

## Common Questions

### Q: Why can't I just use variables?

**A:** You can for local stuff! But for things that multiple systems need to know (score, level, settings), the store ensures everyone gets the same answer and you can debug/save easily.

### Q: Isn't this more complicated than just setting a variable?

**A:** Yes, for simple cases. But for complex games with lots of systems that need to share information, this prevents chaos. Think of it as "a little more work now, way less debugging later."

### Q: Do I have to use it for everything?

**A:** No! Use it for:

- Things multiple systems need to know (score, level)
- Things you want to save (player progress)
- Things you want to debug (complex state bugs)

Don't use it for:

- Local temporary values (button hover state)
- Performance-critical values that change every frame (position, velocity)

### Q: What if I forget to use `.duplicate(true)` in my reducer?

**A:** Your game might work at first, but you'll get weird bugs where changing state in one place affects another. Always duplicate!

### Q: When should I add schemas to my reducers?

**A:** Add them after your first 3-5 reducers are working well! Schemas are like spell-check for your code - they catch mistakes early. If you're working with other developers or your state is getting complex, schemas are super helpful. But for simple projects, you can skip them.

### Q: How do I debug if something's wrong?

**A:**

1. Enable time-travel: `store.enable_time_travel(true)`
2. Play until bug happens
3. Look at action history to see what happened
4. Check state at each step

---

## Summary

The Redux State Store is like a **shared notebook** that:

- Keeps track of everything important in your game
- Makes sure everyone gets the same information
- Remembers what happened (for debugging)
- Makes saving/loading easy
- Helps systems stay independent

**Key Concepts:**

- **M_StateManager**: The notebook keeper
- **State**: The notebook contents
- **Actions**: Request forms to make changes
- **Reducers**: Rules for how to make changes
- **Selectors**: Quick lookups
- **Schemas**: Quality checklists (optional, add after 3-5 reducers work)

**The Pattern:**

1. Something happens in your game
2. Create an action describing what to change
3. Dispatch it to the store
4. Reducer makes the change
5. Everyone gets notified
6. UI/systems react

**Remember:** It's a bit more work upfront, but saves tons of debugging time and makes your game more organized!

---

## Next Steps

Want to learn more? Check out:

- `redux_state_store_architecture.md` - Detailed technical architecture
- `redux_state_store_prd.md` - Full product requirements
- `redux_state_store_tradeoffs.md` - Pros and cons analysis
- `/scripts/state/` - Actual implementation files

**Happy coding!**
