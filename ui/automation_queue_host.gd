extends VBoxContainer
## Container for queued automation rows; rows emit reorder via this signal.

signal reorder_requested(from_index: int, to_index: int)
