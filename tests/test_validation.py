def test_bad_type_rejected(client, test_images):
    img = (test_images/"sample-dog.jpg").read_bytes()
    rv = client.post("/classify", headers={"X-API-Key":"dev-key"},
                     data={"image": (img, "x.txt")})
    assert rv.status_code in (400,415,422)