# Istruzioni per lavorare su Draxtilities

## Contesto e documentazione

Draxtilities aggiunge la protezione degli oggetti a EllesmereUI su WoW Retail.
Richiede EllesmereUI 9.7.3 o successiva; EUI bag controls richiede anche EllesmereUIBags.
WoW carica i file Lua nell'ordine del TOC. Python serve per i controlli del
repository e per i test.

[README.md](README.md) descrive uso e limiti dell'addon.
[RELEASING.md](RELEASING.md) contiene controlli, prove nel client e pubblicazione.
Documenta nel repository le scelte necessarie a chi modifica il codice.

## Mappa del sorgente

| File | Responsabilità |
|---|---|
| `Draxtilities.toc` | Metadati, dipendenze, SavedVariables e ordine di caricamento. |
| `Core.lua` | Namespace `ns`, attivazione di Item Protection e dei suoi controller, eventi, cancellazione e comandi. |
| `Store.lua` | Archivio dei lucchetti per GUID, lettura delle copie, inventario e verifica delle rimozioni osservate. |
| `Bindings.lua` | Cattura del bind di selezione e override temporaneo, rilasciato quando i controlli delle borse sono spenti. |
| `Confirm.lua` | Conferme EUI con nuova verifica degli oggetti e del contesto prima di agire. |
| `PanelGuard.lua` | Controllo condiviso dei pulsanti nativi di vendita junk, asta e riciclo. |
| `TypedDelete.lua` | Conferma DELETE nativa prima della conferma EUI per le eliminazioni che la richiedono. |
| `Modules/Bags.lua` | Azione `bags`: overlay, lucchetto nella fascia inferiore della bag, selezione, vendita manuale e blocco delle spell puntate sulle copie protette. |
| `Modules/Cursor.lua` | Azione `cursor`: eliminazione nel mondo e vendita trascinando sul mercante. |
| `Modules/Merchant.lua` | Azione `merchant`: pulsante Blizzard Sell All Junk. |
| `Modules/Auctions.lua` | Azione `auctions`: pulsante Post della finestra nativa. |
| `Modules/Scrapping.lua` | Azione `scrapping`: pulsante nativo di riciclo. |
| `Options.lua` | Plugin EUI: modulo Item Protection, pagine Settings e Items. |
| `scripts/validate_release.py` | Controlli di manifest, percorsi, versione e file necessari alla release. |
| `tests/test_runtime.py`, `tests/wow_mock.lua` | Regressioni Lua 5.1 con API simulate; non emulano taint o esecuzione protetta. |

Il secondo argomento di `...` è il namespace condiviso `ns`.
I controller delle azioni di Item Protection si registrano con
`ns.Register(key, spec)`; `Start()` restituisce un
controller oppure `nil, motivo`. Il controller espone `Stop()` e, se necessari,
`Refresh`, `Event`, `Cancel` e `Suspend`. `Core.lua` gestisce `running` e gli eventi.
Mantieni l'ordine del TOC coerente quando aggiungi file o dipendenze tra file.
I controller non sono i moduli funzionali di Draxtilities: il solo modulo
esposto attualmente nel plugin EUI è Item Protection. Funzionalità future
avranno un proprio modulo del plugin, con attivazione indipendente; non vanno
aggiunte all'elenco delle azioni di Item Protection.

## Regole delle protezioni

- I moduli funzionali sono indipendenti e disabilitati al primo avvio.
  Item Protection usa `companion.itemProtectionEnabled` come interruttore
  generale e conserva le opzioni delle azioni in `companion.modules` per
  compatibilità. Su una nuova installazione le azioni sono preselezionate ma
  inattive. La migrazione mantiene le vecchie scelte, senza attivare altri ingressi.
  `ns.SetProtectionEnabled` controlla l'intero modulo; `ns.SetProtectionOption`
  cambia un'opzione. Disabilitare il modulo non deve cancellare le preferenze.
- Le impostazioni rimangono in `DraxtilitiesDB.companion`. Preserva i dati esistenti.
- Un lock identifica una copia tramite GUID; un itemID da solo non basta.
  Proteggi solo oggetti con capacità massima di stack pari a 1: la quantità
  attuale nello slot non determina l'idoneità.
- Prima di agire su una copia nelle borse, ricontrolla GUID, posizione e contesto.
  Se i dati necessari non sono disponibili, interrompi l'azione e permetti di
  riprovare dopo il caricamento dei dati. La rimozione manuale di un lock dal
  registro deve restare possibile anche per copie assenti dalle borse.
- In combattimento le protezioni sono sospese. Combattimento, annullamento e
  disattivazione invalidano conferme e permessi.
  Nessuna azione distruttiva deve essere accodata per l'uscita dal combattimento.
- Per i tre controller dei pulsanti nativi, la conferma concede un permesso monouso:
  l'azione viene eseguita alla successiva pressione del pulsante nativo, dopo
  una nuova verifica. Senza copie protette l'azione procede direttamente.
- Non cancellare automaticamente un lock perché la copia non è nelle borse:
  potrebbe essere equipaggiata, in banca, sul cursore o su un altro personaggio.
  La pulizia automatica riguarda solo eliminazioni e ricicli osservati e viene
  verificata dopo `BAG_UPDATE_DELAYED`; una copia venduta conserva il lock.
- Mantieni allineata README alle azioni effettivamente intercettate.
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

Lock or unlock bag items è disponibile in Settings e sul lucchetto nella
fascia inferiore della bag. Per esplicita richiesta dell'utente, l'adattatore
legge i frame con nome `EUI_MainBagFrame` e `EUI_BagMoneyFrame`, verificati
nei sorgenti EUI 9.7.8: non è un'API di registrazione dei pulsanti.
Il pulsante è un frame proprio figlio di EUI_MainBagFrame. Eredita movimento,
scala e visibilità; non agganciare script o funzioni EUI per seguirli e non
modificare ancoraggi, dimensioni, script, campi o SavedVariables di EUI.
La geometria dei figli del footer è letta con le API Frame Blizzard per trovare
uno spazio libero sulla riga inferiore. Riserva l'angolo destro ai controlli
nativi; se manca spazio o la geometria non è disponibile, nascondi il pulsante
e disabilitane il mouse, conservando Settings e bind. Il vecchio campo
`companion.bagButtonPosition` non è usato né cancellato. La barra superiore
non espone un contratto per aggiungere pulsanti: non inserirvi controlli.
La cattura del bind usa un frame proprio,
senza dipendere dal builder interno dei keybind EUI. L'override appartiene a
Draxtilities e viene rimosso alla disattivazione di EUI bag controls o dell'intero
modulo Item Protection senza modificare
le assegnazioni salvate di WoW. Il tasto scelto resta in `companion.bagLockKey`.
Usa `ns.AddSkin(callback)` per i frame creati in ritardo: Core registra un solo
callback pubblico RegisterSkin e applica le primitive anche ai frame successivi.
Items elenca solo i lucchetti salvati, con ricerca e rimozione manuale, anche
per copie assenti e a modulo spento. Non aggiungere filtri o una seconda lista
di copie non protette. Le righe sono frame propri riutilizzati, senza accesso
ai campi interni dei widget EUI. Il tooltip si attiva solo sull'icona, non
sull'intera riga. Usa SetBagItem solo dopo aver
ricontrollato il GUID nello slot, altrimenti il link salvato o l'item ID.
Il prebuild della ricerca EUI non deve leggere l'inventario o creare righe.
La ricerca locale è live: usa un EditBox proprio, perché l'input dei widget EUI
pubblici applica il testo a Invio o alla perdita del focus. Non modificarne gli
script o i campi interni. Campo e righe vanno riutilizzati e riassegnati al nuovo
parent nei rebuild: EUI può sostituire il wrapper della pagina. Conserva focus
e posizione del cursore, ignora gli OnTextChanged da SetText programmatici e
non accumulare righe o callback delle skin a ogni carattere.
InputBoxTemplate seleziona tutto il testo quando riceve il focus: dopo un
rebuild, ripristina il focus, annulla l'evidenziazione con HighlightText(0, 0)
e infine ripristina il cursore, altrimenti il carattere successivo sostituisce
l'intera ricerca. La selezione manuale dell'utente deve restare possibile.
In Settings, completa una riga dispari con una cella label vuota per conservare
le due colonne di DualRow: omettere la cella destra allarga quella sinistra.

Il clic su una copia protetta con SpellCanTargetItem / SpellCanTargetItemID
attivo blocca il puntamento con SpellStopTargeting, incluso Disenchant. Non
eseguire la spell dopo una conferma o in seguito all'uscita dal combattimento.
Il controllo riguarda quel clic nelle borse: EUI Quick Actions usa un pulsante
secure separato e rimane escluso, come le macro che applicano la spell allo slot.

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
virtuale come descritto in RELEASING.md, quindi esegui con quell'interprete:

```text
python -m unittest discover -s tests -v
```

Le dipendenze di sviluppo e i test restano esclusi dal pacchetto installabile.

Per preparare una release usa anche `python scripts/validate_release.py --tag vX.Y.Z`,
sostituendo il tag con la versione desiderata. Lo script controlla metadati e
file; non esegue Lua, non simula WoW e non dimostra assenza di taint.
Per modifiche funzionali scegli le prove pertinenti dalla sezione
"Verifiche nel client" di RELEASING.md. Riporta quali controlli hai eseguito e quali
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
