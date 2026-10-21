from app import app


def test_avaleht_vastab():
    vastus = app.test_client().get("/")
    assert vastus.status_code == 200
    assert "Tervist" in vastus.get_data(as_text=True)
