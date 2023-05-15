# add your create-obituary function here

import requests
from requests_toolbelt.multipart import decoder
import boto3
import base64
import os
import time
import hashlib
import json

client = boto3.client("ssm")

response = client.get_parameters_by_path(
    Path='/the-last-show/',
    Recursive=True,
    WithDecryption=True
)

response = {key["Name"]: key["Value"] for key in response["Parameters"]}

def get_keys(key_path):
    return response[key_path]

dynamodb_resource = boto3.resource("dynamodb")
table = dynamodb_resource.Table("the-last-show-30142625")
    
def upload_to_cloudinary(filename, resource_type = "", extra_fields=()):
    api_key = get_keys("/the-last-show/cloudinary-key")
    cloud_name = "xmanox"
    api_secret = get_keys("/the-last-show/cloudinary-secret-key")

    body = {
        "api_key": api_key
    }

    files = {
        "file": open(filename, "rb")
    }

    timestamp = int(time.time())
    body["timestamp"] = timestamp
    body.update(extra_fields)
    body["signature"] = create_signature(body, api_secret)

    url = f"http://api.cloudinary.com/v1_1/{cloud_name}/{resource_type}/upload".format(cloud_name)
    res = requests.post(url, files=files, data=body)
    return res.json()

def create_signature(body, api_secret):
    exclude = ["api_key", "resource_type", "cloud_name"]
    sorted_body = sort_dictionary(body, exclude)
    query_string = create_query_string(sorted_body)
    query_string_appended = f"{query_string}{api_secret}"
    hashed = hashlib.sha1(query_string_appended.encode())
    signature = hashed.hexdigest()
    return signature

def sort_dictionary(dictionary, exclude):
    return {k: v for k, v in sorted(dictionary.items(), key=lambda item: item[0]) if k not in exclude}

def create_query_string(body):
    query_string = ""
    for idx, (k, v) in enumerate(body.items()):
        query_string = f"{k}={v}" if idx == 0 else f"{query_string}&{k}={v}"

    return query_string

def ask_gpt(name, bornDate, diedDate):
    gpt_key = get_keys("/the-last-show/gpt-key")
    url = "https://api.openai.com/v1/completions"
    prompt = f"write an obituary about a fictional character named {name} who was born on {bornDate} and died on {diedDate}."
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {gpt_key}"
    }
    body = {
        "model": "text-curie-001",
        "prompt": prompt,
        "max_tokens": 500,
        "temperature": 0.2
    }
    res = requests.post(url, headers=headers, json=body)
    return res.json()["choices"][0]["text"]

def read_this(prompt):
    client = boto3.client('polly')
    response = client.synthesize_speech(
        Engine = 'standard', 
        LanguageCode = 'en-US', 
        OutputFormat = 'mp3', 
        Text = prompt, 
        TextType = 'text', 
        VoiceId = 'Salli'
    )

    filename = "/tmp/polly.mp3"
    with open(filename, "wb") as f:
        f.write(response["AudioStream"].read())

    return filename

def lambda_handler(event, context):
    body = event["body"]
    if event["isBase64Encoded"]:
        body = base64.b64decode(body)
    content_type = event["headers"]["content-type"]
    data = decoder.MultipartDecoder(body, content_type)

    binary_data = [part.content for part in data.parts]
    name = binary_data[1].decode()
    bornDate = binary_data[2].decode()
    diedDate = binary_data[3].decode()

    key = "obituary.png"
    file_name = os.path.join("/tmp", key)
    with open(file_name, "wb") as f:
        f.write(binary_data[0])

    res = upload_to_cloudinary(file_name, resource_type="image", extra_fields={"eager": "e_art:zorro"})
    cloudinary_url = res["eager"][0]["url"]
    gpt_description = ask_gpt(name, bornDate, diedDate)
    voice = read_this(gpt_description)
    mp3 = upload_to_cloudinary(voice, resource_type="raw")

    item = {
        'name': name,
        'bornDate': bornDate,
        'diedDate': diedDate,
        'cloudinary_url': cloudinary_url,
        'obituary': gpt_description,
        'creation': int(time.time()),
        "polly_url": mp3["secure_url"]
    }

    try:
        table.put_item(Item=item)
        return {"statusCode": 200, 
                "body": "Success"}
    except Exception as exp:
        print(f"exception: {exp}")
        return {
            "statusCode": 401,
                "body": json.dumps({
                    "message": str(exp)
            })
        }