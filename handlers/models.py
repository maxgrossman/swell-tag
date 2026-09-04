from typing import Optional, get_origin
from dataclasses import dataclass
from functools import wraps

@dataclass
class EventModel:
    models: list[str]
    ranges: list[list[int]]
    environment: str = 'prod'

    def __post_init__(self):
        for field_name, field in self.__dataclass_fields__.items():
            expected_type = field.type
            value = getattr(self, field_name)
            origin = get_origin(expected_type)

            to_check = origin if origin is not None else expected_type
            valid = isinstance(value, to_check)

            if not valid:
                raise TypeError(
                    f"Field '{field_name}' must be of type {str(to_check)}, "
                    f"got {str(value)}"
                )

def enforce_model(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        # __post_init__ will throw if not valid.
        valid = EventModel(**args[0])
        args_next = [a for a in args]
        args_next[0] = valid
        return func(*tuple(args_next), **kwargs)
    return wrapper

