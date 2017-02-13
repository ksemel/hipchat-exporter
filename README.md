# hipchat-exporter
Export all the one-to-one and room history that your user has access to

# How to Use

1. Create a `.hipchat_token` file with your hipchat token in it

2. Run `./get-rooms.sh` and `./get-users.sh` first to create a full list of rooms and users you have access to.

3. If you don't want to get everything, prune the files room_ids.txt and user_ids.txt to the rooms and users you want.  You can find the names of rooms and users in rooms.json and users.json.

4. Run `./get-room-history.sh` and `./get-user-history.sh` to generate the json files of each room.

5. Run `./get-room-files.sh` and `./get-user-files.sh` to download all the files uploaded to the room and optionally copy them to an s3 bucket.
