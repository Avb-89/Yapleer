from yandex_music import Client

TOKEN = "y0__wgBELfYjxIY3vgGINyr1IYYYYqQbjpHb__DbxoBFDpPZhATEnk"

client = Client(TOKEN).init()

station = "user:onyourwave"

tracks = client.rotor_station_tracks(station, settings2=True)

print("BATCH:", tracks.batch_id)
print("COUNT:", len(tracks.sequence))

item = tracks.sequence[0]
track = item.track

print("TRACK ID:", track.id)
print("TITLE:", track.title)
print("ARTISTS:", ", ".join(artist.name for artist in track.artists))

infos = track.get_download_info()
best = sorted(infos, key=lambda x: x.bitrate_in_kbps or 0)[-1]

print("CODEC:", best.codec)
print("BITRATE:", best.bitrate_in_kbps)

direct_url = best.get_direct_link()
print("DIRECT URL:")
print(direct_url)
