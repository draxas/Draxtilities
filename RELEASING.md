# Test e pubblicazione

## Controlli locali

Il controllo del manifest richiede Python 3.9 o successivo:

```text
python scripts/validate_release.py
git diff --check
```

Per i test Lua 5.1, crea un ambiente virtuale e installa le dipendenze di sviluppo.
Su Windows, da PowerShell:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
```

Su Linux o macOS, usa `./.venv/bin/python` al posto di `.\.venv\Scripts\python.exe`.
Dopo l'installazione delle dipendenze puoi rilanciare direttamente il comando dei test.

I test usano API simulate. Verificano la logica dei lucchetti e delle conferme,
ma non il comportamento dei frame protetti, il taint o i clic nel client.

## Verifiche nel client

Per le prove di vendita, eliminazione e riciclo usa oggetti che puoi perdere.

1. Al primo avvio Item Protection deve essere disattivato, con le azioni
   preselezionate ma inattive. Abilitalo e disabilitalo, controllando che lucchetti
   e preferenze restino salvati e che le borse EUI funzionino normalmente da spento.
2. Abilita Item Protection ed EUI bag controls, riapri le borse e prova
   **Lock or unlock bag items**, il bind e `/dt lock` nei layout Grid, List e
   Compact, con scrolling, scala UI diversa e borsa reagenti separata.
   Verifica due copie identiche e il rifiuto di uno stackabile in quantità 1.
3. Items deve mostrare solo le copie protette. Prova ricerca e paginazione con
   due copie identiche, poi Unlock per una copia assente a modulo spento.
   Verifica il tooltip WoW solo sulle icone: il resto della riga non deve
   attivarlo. Sposta la copia prima del mouse hover
   e controlla che non venga mostrato l'oggetto finito al suo posto nello slot.
   Passa da Items a Settings e torna: righe e lucchetti devono aggiornarsi.
4. Prova la vendita con clic destro e trascinando sul mercante. Annulla e
   conferma entrambe le operazioni; una vendita deve conservare il lock nel registro.
5. Trascina fuori dalle borse un oggetto raro o epico protetto. Prova DELETE
   errato e corretto, sia con il mouse sia con Invio, poi annulla o conferma il popup EUI.
6. Per Sell All Junk, Post e riciclo, verifica la sequenza pulsante → conferma
   EUI → pulsante. Cambia copia, selezione, prezzo o quantità dopo la conferma:
   l'operazione modificata deve richiederne un'altra.
7. Entra in combattimento durante una conferma o dopo averla accettata.
   Controlla che le protezioni vengano sospese e che all'uscita non parta alcuna
   azione. Fuori dal combattimento, disabilita Item Protection e verifica che i pulsanti
   nativi tornino al normale funzionamento.
8. Annulla un'eliminazione o interrompi un riciclo, poi vendi la stessa copia:
   il suo lock deve rimanere nel registro. Controlla invece la rimozione del
   record dopo un'eliminazione o un riciclo completati.
9. Esegui `/reload` e controlla la persistenza di lucchetti, stato del modulo e
   preferenze delle azioni. Prova anche il passaggio dalle vecchie impostazioni:
   devono essere ripristinate solo le azioni precedentemente attive.
10. Configura e cancella un bind in Settings, anche usando un tasto già
    assegnato. Controlla Save shortcut, Clear shortcut, Esc e Cancel. Disabilita
    EUI bag controls e poi l'intero modulo: il tasto deve tornare alla sua
    assegnazione normale. Riabilita i controlli ed esegui `/reload`: il bind scelto
    deve essere ripristinato. Entra in combattimento durante la scelta e durante
    la selezione: nessuna delle due deve ripartire da sola alla fine.
11. Apri Items dopo una ricerca globale EUI. Controlla ricerca, tooltip,
    pulsanti e aggiornamenti dopo spostamenti, cambi di lock e combattimento,
    anche con scala UI e finestra EUI ridotte. La lista deve filtrarsi a ogni
    carattere, anche con Backspace, incolla e inserimento a metà del testo,
    conservando focus e cursore, senza selezionare automaticamente il testo e
    sostituirlo al carattere successivo. Prova anche Ctrl+A per una sostituzione
    intenzionale. Svuota il campo e cambia pagina. Verifica che
    gli aggiornamenti dell'inventario non interrompano la digitazione.
12. In Settings, Scrap button deve occupare solo la colonna sinistra. Nelle
    borse prova il lucchetto dorato nella fascia inferiore: clic sinistro per
    selezionare, destro per Items, sfondo verde durante la selezione. Sposta e
    ridimensiona la bag: il pulsante deve seguirla senza coprire oro, valute o
    i controlli nativi. Prova Grid, List, Compact, scala diversa, molte valute,
    finestre bloccate e sbloccate, banca aperta, borse vuote e ricerca senza
    risultati. Se manca spazio il pulsante deve sparire e non intercettare clic.
    Verifica chiusura, riapertura, reload, combattimento e disattivazione:
    la selezione non deve riattivarsi da sola. Nessun file EUI va modificato.
13. Lancia Disenchant e fai clic su una copia protetta nelle borse EUI: il
    puntamento deve essere annullato, l'oggetto e il lock conservati. Ripeti con
    la copia spostata dopo il disegno dello slot. Non dichiarare coperti i clic
    sulle Quick Actions EUI o le macro che applicano la spell direttamente allo slot.

Riporta nel riepilogo della modifica quali prove sono state eseguite.

## Pubblicare una versione

1. Aggiorna `## Version` in `Draxtilities.toc`.
2. Aggiungi le novità in cima a `CHANGELOG.md`, sotto un'intestazione con la stessa versione.
3. Esegui i controlli locali e le prove nel client pertinenti alla modifica.
4. Crea un commit che descriva le modifiche e pubblicalo su `main`.
5. Crea e pubblica un tag annotato `v<versione>`.

Per esempio, dopo aver aggiornato TOC e changelog alla versione `0.1.2`:

```powershell
python scripts/validate_release.py --tag v0.1.2
git add .
git commit
git push origin main
git tag -a v0.1.2 -m "Draxtilities 0.1.2"
git push origin v0.1.2
```

Sono accettate versioni `X.Y.Z`, `X.Y.Z-alpha.N` e `X.Y.Z-beta.N`, con il contatore
`N` a partire da 1. Per esempio, una beta usa `0.1.2-beta.1` nel TOC e
`v0.1.2-beta.1` come tag e viene pubblicata come prerelease.
Per correggere una versione già distribuita, pubblica una nuova versione con un nuovo tag.

## GitHub Actions e pacchetto

Il workflow [Validate and release](.github/workflows/release.yml) esegue test,
controllo del manifest e packaging senza upload sui push a `main`, nelle pull
request e all'avvio manuale. Sui push dei tag `v*`, dopo questi controlli,
crea anche una release GitHub e allega:

- `Draxtilities-<tag>.zip`, con `Draxtilities/Draxtilities.toc` e i file dell'addon.
- `release.json`, con i metadati usati dai gestori di addon.

Il nome della cartella e le esclusioni sono definiti in `.pkgmeta`.
Test, dipendenze di sviluppo e istruzioni per i manutentori non vanno nello ZIP.

Il job di pubblicazione usa il `GITHUB_TOKEN` fornito da GitHub con
`contents: write`. Il repository deve consentire GitHub Actions e questi permessi.
Segui l'esecuzione nella scheda **Actions** e controlla gli allegati nella pagina
[Releases](https://github.com/draxas/Draxtilities/releases).

## Aggiornamenti tramite WoWUp

L'URL da condividere è quello del repository:

```text
https://github.com/draxas/Draxtilities
```

WoWUp distribuisce le release con lo ZIP installabile allegato. I normali push
su `main` non aggiornano l'addon agli utenti. Un collegamento diretto allo ZIP
serve per un'installazione singola, senza controlli sugli aggiornamenti.

Durante lo sviluppo, tieni il checkout Git separato dalla copia gestita da WoWUp.

## Riferimenti

- [WoWUp: installazione da URL](https://wowup.io/guide/get-addons/overview)
- [BigWigs Packager](https://github.com/BigWigsMods/packager)
- [Configurazione .pkgmeta](https://github.com/BigWigsMods/packager/wiki/Preparing-the-PackageMeta-File)
