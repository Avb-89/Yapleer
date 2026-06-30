from yandex_music import Client


def on_code(code):
    print()
    print("Открой в браузере:")
    print(code.verification_url)
    print()
    print("И введи код:")
    print(code.user_code)
    print()
    print("После подтверждения вернись в терминал и подожди...")
    print()


def main():
    client = Client()
    token = client.device_auth(on_code=on_code)

    print()
    print("ACCESS TOKEN:")
    print(token.access_token)
    print()


if __name__ == "__main__":
    main()
PY
