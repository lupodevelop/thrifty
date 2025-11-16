# Golden tooling

Script per generare i payload Compact Protocol di riferimento.

## Dipendenze

- Python 3.11+
- `thriftpy2` (`pip install thriftpy2`)

## Uso

```sh
# Ensure you have the Python deps installed (see tools/requirements.txt)
python tools/golden/generate_compact_vectors.py
```

Per default i file generati vengono salvati in `artifact/golden` (anziché `ref/golden`).
Questo permette di escludere `ref/` dal repo e tenere i payload generati come artefatti locali o CI.
I test Gleam sono stati aggiornati per leggere da `artifact/golden`.
