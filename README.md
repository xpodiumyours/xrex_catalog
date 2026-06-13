# X-rex Catalog

X-rex, VitrinX icin ayrik gelistirilen masrafsiz katalog taslak uygulamasidir.

Ana kurallar:

- Ucretli API yok.
- AI API yok.
- Backend yok.
- Supabase/Firebase yok.
- VitrinX koduna dokunulmaz.

Faz 1:

- Fotoğraf veya ekran goruntusu yerel referans olarak secilir.
- Kullanici urun taslaklarini elle duzenler.
- Son ekranda okunabilir JSON ciktisi alinir.

Faz 2:

- Android tarafinda Google ML Kit Text Recognition ile cihaz ici OCR denenir.
- OCR metni mevcut yerel metin parserina aktarilir.
- Web tarafinda OCR desteklenmez; web akisi manuel metin/taslak olarak korunur.
