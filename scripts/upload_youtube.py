#!/usr/bin/env python3
import argparse
import json
import os
from pathlib import Path

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

SCOPES=["https://www.googleapis.com/auth/youtube.upload"]

def get_credentials(client_secret:Path, token_file:Path):
    creds=None
    if token_file.exists():
        creds=Credentials.from_authorized_user_file(str(token_file),SCOPES)
    if creds and creds.expired and creds.refresh_token:
        creds.refresh(Request())
    if not creds or not creds.valid:
        if not client_secret.exists():
            raise SystemExit(f"OAuth client file not found: {client_secret}")
        flow=InstalledAppFlow.from_client_secrets_file(str(client_secret),SCOPES)
        creds=flow.run_local_server(port=0,open_browser=True)
    token_file.parent.mkdir(parents=True,exist_ok=True)
    token_file.write_text(creds.to_json())
    return creds

def main():
    p=argparse.ArgumentParser()
    p.add_argument("video",nargs="?",default="build/lesson.mp4")
    p.add_argument("--lesson",default="build/lesson.json")
    p.add_argument("--client-secret",default=os.environ.get("YOUTUBE_CLIENT_SECRET","youtube-client-secret.json"))
    p.add_argument("--token",default="build/youtube-token.json")
    p.add_argument("--title")
    p.add_argument("--description")
    p.add_argument("--description-file")
    p.add_argument("--privacy",choices=["private","unlisted","public"],default="private")
    p.add_argument("--category",default="27")
    p.add_argument("--tags",default="")
    a=p.parse_args()

    video=Path(a.video)
    if not video.exists(): raise SystemExit(f"Video does not exist: {video}")
    lesson={}
    lp=Path(a.lesson)
    if lp.exists(): lesson=json.loads(lp.read_text())
    title=a.title or lesson.get("title") or video.stem

    description=None
    if a.description_file:
        dp=Path(a.description_file)
        if not dp.exists(): raise SystemExit(f"Description file not found: {dp}")
        description=dp.read_text(encoding="utf-8").strip()
    if not description:
        description=a.description or lesson.get("description") or (lesson.get("subtitle","")+"\n\nGenerated with Richlesson.").strip()

    tags=[x.strip() for x in a.tags.split(",") if x.strip()]
    creds=get_credentials(Path(a.client_secret),Path(a.token))
    youtube=build("youtube","v3",credentials=creds)
    body={"snippet":{"title":title[:100],"description":description[:5000],"categoryId":str(a.category)},"status":{"privacyStatus":a.privacy,"selfDeclaredMadeForKids":False}}
    if tags: body["snippet"]["tags"]=tags
    media=MediaFileUpload(str(video),mimetype="video/mp4",resumable=True,chunksize=8*1024*1024)
    request=youtube.videos().insert(part="snippet,status",body=body,media_body=media)
    print(f"Uploading: {title}\nPrivacy: {a.privacy}")
    response=None
    while response is None:
        status,response=request.next_chunk()
        if status: print(f"\rUpload: {int(status.progress()*100)}%",end="",flush=True)
    print("\rUpload: 100%")
    video_id=response["id"]
    result={"ok":True,"video_id":video_id,"title":title,"privacy":a.privacy,"url":f"https://youtu.be/{video_id}"}
    Path("build/youtube-upload.json").write_text(json.dumps(result,indent=2))
    print(f"✓ https://youtu.be/{video_id}")

if __name__=="__main__": main()
