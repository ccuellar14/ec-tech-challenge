from main import handler

def test_lambda():
    response = handler({'name': 'test'}, None)
    assert response['statusCode'] == 200