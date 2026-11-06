# Istruzioni per lavorare su Draxtilities

## Contesto e documentazione

Draxtilities è un addon Lua per World of Warcraft Retail 12.1+, dipendente da
EllesmereUI originale 9.7.3 o successiva. EllesmereUIBags è opzionale ed è
necessario per Bag Locks. Non ci sono dipendenze Python per l'esecuzione in WoW,
compilazione del Lua o librerie EUI incorporate nel repository.

Il contesto necessario deve restare nei file del progetto, senza dipendere
dalla cronologia di una chat o da percorsi assoluti del computer dello sviluppatore.
Consulta [README.md](README.md) per comportamento, copertura e prove nel client;
[RELEASING.md](RELEASING.md) per packaging e pubblicazione. Leggi i sorgenti
interessati dalla richiesta prima di modificarli.

## Mappa del sorgente

| File | Responsabilità |
|---|---|
| `Draxtilities.toc` | Metadati, dipendenze, SavedVariables e ordine di caricamento. |
| `Core.lua` | Namespace `ns`, registrazione e attivazione moduli, eventi, cancellazione e comandi `/dt` e `/draxtilities`. |
| `Store.lua` | Archivio dei lucchetti per GUID, lettura delle copie, inventario e verifica delle rimozioni osservate. |
| `Confirm.lua` | Conferme EUI con nuova verifica degli oggetti e del contesto prima di agire. |
| `PanelGuard.lua` | Controllo condiviso dei pulsanti nativi di vendita junk, asta e riciclo. |
| `TypedDelete.lua` | Conferma DELETE nativa prima della conferma EUI per le eliminazioni che la richiedono. |
| `Modules/Bags.lua` | Modulo `bags`: overlay, selezione dei lucchetti e vendita manuale dalle bag EUI. |
| `Modules/Cursor.lua` | Modulo `cursor`: eliminazione nel mondo e vendita trascinando sul mercante. |
| `Modules/Merchant.lua` | Modulo `merchant`: pulsante Blizzard Sell All Junk. |
| `Modules/Auctions.lua` | Modulo `auctions`: pulsante Post della finestra nativa. |
| `Modules/Scrapping.lua` | Modulo `scrapping`: pulsante nativo di riciclo. |
| `Options.lua` | Plugin EUI, pagine Modules, Items e Coverage. |
| `scripts/validate_release.py` | Controlli di manifest, percorsi, versione e file necessari alla release. |
| `tests/test_runtime.py`, `tests/wow_mock.lua` | Regressioni Lua 5.1 con API simulate; non emulano taint o esecuzione protetta. |

I file Lua condividono il namespace ricevuto tramite `local _, ns = ...`.
I moduli si registrano con `ns.Register(key, spec)`; `Start()` restituisce un
controller oppure `nil, motivo`. Il controller espone `Stop()` e, se necessari,
`Refresh`, `Event`, `Cancel` e `Suspend`. `Core.lua` gestisce `running` e gli eventi.
Mantieni l'ordine del TOC coerente quando aggiungi file o dipendenze tra file.

## Invarianti delle protezioni

- I moduli sono indipendenti e disabilitati al primo avvio; le preferenze salvate
  vengono ripristinate agli avvii successivi.
- Le impostazioni rimangono in `DraxtilitiesDB.companion`. Preserva i dati esistenti.
- Un lock identifica una copia tramite GUID, non un itemID. Sono ammessi solo
  oggetti con capacità massima di stack pari a 1, anche quando la quantità è 1.
- Prima di modificare un lock o compiere un'azione distruttiva, ricontrolla GUID,
  posizione e contesto. Se i dati necessari non sono disponibili, interrompi
  l'azione e permetti di riprovare dopo il caricamento dei dati.
- Combattimento, annullamento e disattivazione invalidano conferme e permessi.
  Nessuna azione distruttiva deve essere accodata per l'uscita dal combattimento.
- Per i tre moduli dei pulsanti nativi, la conferma concede un permesso monouso:
  l'azione viene eseguita alla successiva pressione del pulsante nativo, dopo
  una nuova verifica. Senza copie protette l'azione procede direttamente.
- L'assenza di una copia dalle bag non giustifica la cancellazione del lock:
  potrebbe essere equipaggiata, in banca, sul cursore o su un altro personaggio.
  La pulizia automatica riguarda solo eliminazioni e ricicli osservati e viene
  verificata dopo `BAG_UPDATE_DELAYED`; una copia venduta conserva il lock.
- Mantieni allineate README e Coverage alle azioni effettivamente intercettate.
  EUI Sell Junk e vendita automatica, posta, scambi, crafting e gli altri ingressi
  alle spell sugli oggetti non sono coperti dalle protezioni attuali.

## Integrazione con EUI e Blizzard

Usa le API pubbliche: `RegisterPlugin` e `OpenPlugin` per le opzioni,
`RegisterSkin` per i frame creati da Draxtilities e
`EUI_Bags.RegisterItemOverlayIcon` / `UnregisterItemOverlayIcon` per le bag.
Non sostituire o agganciare funzioni EUI, non accedere a `_ModuleNS` o ad altri
internals e non modificare file, categorie o SavedVariables di EllesmereUI.
La lettura di `EllesmereUI.ItemProtection` in Core è solo un controllo di conflitto.

I page builder devono tollerare la ricerca EUI e il suo passaggio di prebuild:
usa `EllesmereUI.IsSearchPrebuild()` per evitare effetti sullo stato del gioco.
I dati del callback degli overlay sono validi solo durante la chiamata;
mantieni lo stato dei controlli in tabelle di Draxtilities, senza scriverlo sui
pulsanti EUI o Blizzard. Rispetta i vincoli dei frame protetti e del combattimento.
Preserva i controlli sui valori segreti quando leggi gli identificativi Blizzard.

I contratti delle API esterne sono nel pacchetto ufficiale di EllesmereUI:

- `EllesmereUI/PLUGINS_API.md`: registrazione, pagine, widget, ricerca e cache.
- `EllesmereUI/SKINNING_API.md`: skin dei frame del proprio addon.
- `EllesmereUIBags/EUI_Bags_Slots.lua`: contratto del callback degli overlay.

In un'installazione WoW queste cartelle possono essere sorelle del checkout.
Un clone isolato non le contiene: per cambiare un'integrazione, verifica le
firme nella copia ufficiale compatibile indicata nel README. Non dedurre
l'esistenza di un'API dal solo nome e non aggiungere sorgenti EUI al pacchetto.

## Convenzioni e verifiche

Segui `.editorconfig` e `.gitattributes`: UTF-8, LF e quattro spazi per il codice.
Mantieni identificatori e testi UI nello stile inglese esistente; la documentazione
del progetto è in italiano. Limita le nuove variabili globali e usa il namespace.
Rispetta le maiuscole dei percorsi: il packaging gira su Linux.

Dalla root, con Python 3.9 o successivo:

```text
python scripts/validate_release.py
git diff --check
```

Per le regressioni funzionali, installa `requirements-dev.txt` in un ambiente
virtuale come descritto nel README, quindi esegui con quell'interprete:

```text
python -m unittest discover -s tests -v
```

Le dipendenze di sviluppo e i test restano esclusi dal pacchetto installabile.

Per preparare una release usa anche `python scripts/validate_release.py --tag vX.Y.Z`,
sostituendo il tag con la versione desiderata. Lo script controlla metadati e
file; non esegue Lua, non simula WoW e non dimostra assenza di taint.
Per modifiche funzionali scegli le prove pertinenti dalla sezione
"Verifiche nel client" del README. Riporta quali controlli hai eseguito e quali
prove nel client restano da fare, senza dichiarare esiti non osservati.

## Git e distribuzione

I messaggi di commit devono descrivere le modifiche concrete, in inglese e
all'imperativo, per esempio `Fix GUID validation before protected item actions`.
Evita messaggi che descrivono soltanto la preparazione o la pubblicazione.
Esegui commit, push e creazione di tag quando richiesti dall'utente.

Per le release mantieni coerenti `## Version` nel TOC, la prima sezione di
`CHANGELOG.md` e il tag `v<versione>`. I push su `main` eseguono la validazione;
il push di un tag di versione attiva anche il packaging e la release GitHub.
I dettagli operativi sono in RELEASING.md.
`.pkgmeta` deve mantenere la cartella installabile `Draxtilities/` ed escludere
gli strumenti di sviluppo e questo file dallo ZIP. Le istruzioni per gli agent
rimangono nel repository; `.gitignore` non deve escludere `AGENTS.md`.
