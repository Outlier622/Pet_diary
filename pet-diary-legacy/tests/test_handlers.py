def test_unauthorized_without_key(client, test_images):
    img = open(test_images/"sample-dog.jpg","rb")
    rv = client.post("/classify", data={"image": (img, "img.jpg")})
    assert rv.status_code == 401