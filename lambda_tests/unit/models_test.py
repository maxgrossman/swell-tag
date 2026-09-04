import pytest
from handlers.models import EventModel, enforce_model

def test_post_init_works():
    assert True == isinstance(EventModel(models=[],ranges=[]), EventModel)

def test_enforce_model():
    @enforce_model
    def handler(event, context):
        return True

    assert True == handler({"models":[], "ranges":[]}, {})