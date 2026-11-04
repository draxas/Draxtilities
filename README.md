# Draxtilities

Addon separato per World of Warcraft Retail Midnight 12.1+, con moduli
indipendenti e integrazione tramite le API pubbliche dell'EllesmereUI originale.
Richiede **EllesmereUI 9.7.3 o successiva**.
Il suo ZIP contiene soltanto Draxtilities; EllesmereUI va installato separatamente.

## Installazione con WoWUp

Installa EllesmereUI 9.7.3 o successiva. In WoWUp seleziona il client Retail,
apri **Get Addons → Install from URL** e incolla l'indirizzo del repository:

```text
https://github.com/draxas/Draxtilities
```

L'installazione da URL diventa disponibile dopo la pubblicazione della prima
[release con lo ZIP dell'addon](https://github.com/draxas/Draxtilities/releases).
Le nuove release vengono rilevate da WoWUp e installate tramite **Update**
o con gli aggiornamenti automatici abilitati. Usa l'URL del repository:
un link diretto allo ZIP permette soltanto un'installazione singola.

Per segnalare problemi usa le [issue GitHub](https://github.com/draxas/Draxtilities/issues).

## Installazione e primo avvio

1. Chiudi WoW e conserva un backup di `WTF` e delle cartelle degli addon.
2. **Installa o aggiorna il pacchetto ufficiale completo di EllesmereUI tramite
   WoWUp, alla versione 9.7.3 o successiva.** Non cancellare `WTF`:
   contiene le impostazioni degli addon.
   Se è installato il vecchio addon omonimo Draxtilities/Padlock, sposta la sua
   intera cartella fuori da AddOns prima di estrarre questa versione: non unire
   le due installazioni. Poi abilita il nuovo Draxtilities nella lista addon.
3. Estrai lo ZIP di Draxtilities direttamente in `_retail_/Interface/AddOns`.
   Devi ottenere `AddOns/Draxtilities/Draxtilities.toc`, accanto alle cartelle
   ufficiali `EllesmereUI`, `EllesmereUIBags`, ecc.
4. Avvia WoW e digita `/dt`. Nelle opzioni EUI appare una sezione distinta
   **Draxtilities**, con le pagine **Modules**, **Items** e **Coverage**.
5. Tutti i moduli partono **disabilitati**. Leggi Coverage e abilita quelli
   desiderati. Per l'integrazione delle bag serve anche EllesmereUIBags attivo.
6. Dopo aver abilitato Bag Locks, apri o riapri una volta le bag: l'API di EUI
   fornisce a Draxtilities gli slot durante la loro visualizzazione.

Il rilevamento della vecchia protezione ancora attiva impedisce di abilitare
una seconda protezione sopra il fork. Non installiamo né sovrascriviamo
automaticamente file nella cartella del gioco.

## Moduli inclusi

| Modulo | Flussi coperti |
|---|---|
| Bag Locks | Badge per la copia rappresentata dallo slot EUI; selezione con `/dt lock`; conferma della vendita manuale con clic destro al mercante. |
| Cursor Safeguards | Eliminazione trascinando una copia protetta nel mondo; vendita trascinandola sul mercante. Per gli oggetti che lo richiedono, prima compare DELETE nativo e poi la conferma EUI. |
| Native Junk Sale | Pulsante Blizzard **Sell All Junk**. Non comprende il pulsante **Sell Junk** di EUI. |
| Native Auctions | Pulsante **Post** della finestra nativa per oggetti non stackabili. Ricontrolla GUID, posizione, prezzo, durata e quantità. In presenza di copie protette corrispondenti si pubblica una copia alla volta. |
| Native Scrapping | Pulsante nativo di riciclo, con verifica delle copie selezionate e pulizia dei lucchetti delle copie effettivamente consumate. |

Quando l'azione coinvolge copie protette, i tre pulsanti nativi richiedono
questa sequenza:

1. Premi il pulsante nativo per aprire la conferma EUI.
2. Conferma il popup EUI.
3. Premi **di nuovo lo stesso pulsante nativo** per eseguire l'azione.

Le due pressioni del pulsante sono separate dalla conferma del popup EUI.
La conferma autorizza l'azione; la successiva pressione del pulsante nativo
ricontrolla oggetto e contesto ed esegue una sola azione. Modifiche, annullamento,
disattivazione o ingresso in combattimento richiedono una nuova conferma.
Uscire dal combattimento non ripete alcuna azione.
Le azioni che non coinvolgono copie protette procedono subito.

## Comandi e gestione delle copie

| Comando | Azione |
|---|---|
| `/dt` oppure `/draxtilities` | Apre Modules nelle opzioni EUI. |
| `/dt items` | Apre il registro e l'elenco delle copie. |
| `/dt lock` | Attiva/disattiva la selezione nelle bag, se Bag Locks è abilitato. |
| `/dt cursor` | Protegge/sblocca la copia tenuta sul cursore, con almeno un modulo abilitato. |

Puoi mettere `/dt lock` in una macro e assegnarla a un tasto. In selezione,
clic sinistro protegge/sblocca, clic destro o Esc termina la modalità.
La piccola barra di Draxtilities è spostabile e contiene **Done** e
**Manage every copy**. Il mercante e la chiusura delle bag terminano la selezione.
Esci prima dalle modalità native Junk/Pin di EUI: Draxtilities non le modifica
e non ne coordina gli stati interni.

**Items → Protected only** sostituisce il vecchio filtro nella sidebar delle bag.
Disattivando Protected only vengono mostrate le singole copie non stackabili
nelle borse del personaggio, anche quando EUI le raggruppa in uno slot.
Bag, slot e suffisso GUID permettono di distinguerle. Il pulsante Refresh
aggiorna l'elenco; ogni azione ricontrolla la copia prima di modificarne il lock.

Sono ammessi oggetti con capacità massima di stack pari a 1. Un materiale
stackabile presente in quantità 1 non è ammesso. La protezione è per GUID,
non per itemID: due copie identiche possono avere stati diversi.

## Integrazioni escluse e alternative

Un lucchetto è un controllo dei percorsi elencati, **non un blocco del gioco
contro qualsiasi distruzione**. I moduli possono essere disabilitati separatamente.

| Integrazione non portata | Alternativa |
|---|---|
| Pulsante aggiunto all'header EUI e riordino del relativo testo | Macro `/dt lock` e barra autonoma di Draxtilities. L'header originale resta gestito da EUI. |
| Filtro Protected Items sotto Pinned Items | Pagina Items con Protected only. |
| Cambiamento delle regole interne di raggruppamento | Pagina Items, che elenca ogni copia senza dipendere dal raggruppamento delle bag. I badge si riferiscono alla copia rappresentata dallo slot. |
| Modifica della modalità Junk e selezione condivisa con il lucchetto | Junk originale resta intatto; la selezione Lock ha controlli propri. |
| Vendita automatica EUI e relativo pulsante Sell Junk | **Disabilita le vendite automatiche** in EUI e negli altri addon. Usa le vendite manuali confermate, oppure il pulsante Blizzard con Native Junk Sale abilitato. Il pulsante EUI rimane fuori dalla protezione. |
| Apertura automatica dei contenitori | Disabilita l'automazione e aprili manualmente dopo aver controllato la copia in Items. |
| Disincantamento, spell sugli oggetti ed EUI Quick Actions | Sblocca esplicitamente la copia scelta in Items prima di procedere. Il nostro controllo sullo slot blocca il targeting diretto, ma gli altri ingressi alle spell non vengono intercettati. |
| Vecchia categoria persistita “Draxtilities · Padlock” | Rimuovila dall'editor delle categorie di EUI. Draxtilities non modifica categorie o impostazioni di un altro addon. |
| Posta, scambi, crafting, quest, macro e pulsanti di altri addon | Nessun blocco automatico; verifica e sblocca manualmente le copie interessate. |

Per una futura integrazione identica nelle bag servirebbero API ufficiali per
pulsanti dell'header, filtri per GUID, selezione e controlli prima delle
automazioni. Un'altra possibilità è aggiungere a Draxtilities una propria vendita
sicura con una lista junk indipendente; questa versione non la implementa.

## Dati e pulizia

Impostazioni e lucchetti risiedono in **DraxtilitiesDB.companion**, separati
da profili e import/export di EUI. Il file SavedVariables è
`WTF/Account/<account>/SavedVariables/Draxtilities.lua`.
Al primo avvio tutti i moduli sono disabilitati; agli avvii successivi vengono
ripristinate le preferenze e i lucchetti già salvati da Draxtilities.

Il registro può contenere copie di altri personaggi, in banca o equipaggiate:
la sola assenza dalle bag non cancella un lock. La pulizia automatica riguarda
solo le distruzioni osservate dopo le azioni di eliminazione/riciclo gestite
da Draxtilities, dopo l'aggiornamento delle borse ricevuto dal server. Un lock
non scompare se l'azione viene annullata, fallisce o l'oggetto viene spostato.
Per azioni non osservate, addon disabilitato o reload durante un'azione, usa
la rimozione manuale del record. Le copie vendute conservano il lock nel registro.

## Verifiche nel client

L'assenza di taint, la correttezza visiva e la gestione nativa del mouse
devono essere verificate nel client.
Usa copie sacrificabili per le prove di distruzione.

1. Con tutti i moduli OFF verifica Junk originale, header, ricerca e bag.
2. Abilita Bag Locks, riapri le bag e prova `/dt lock` con Grid, List, Compact,
   scrolling, scala UI e borsa reagenti separata. Prova due copie identiche e
   uno stackabile presente in quantità 1.
3. Controlla Items con entrambi i filtri e sposta un oggetto prima di premere
   un pulsante dell'elenco: un'altra copia non deve ricevere quel lock.
4. Prova vendita manuale e trascinamento sul mercante, annullando e confermando.
5. Per un raro/epico protetto trascinato fuori dalle bag prova DELETE errato,
   DELETE corretto con mouse e con Invio, quindi annulla/conferma il popup EUI.
6. Per junk nativo, asta e riciclo con copie protette premi il pulsante,
   conferma il popup EUI e premi ancora il pulsante nativo. Cambia selezione,
   prezzo, quantità o copia dopo la conferma: serve una nuova autorizzazione.
   Senza copie protette, l'azione deve procedere subito.
7. Entra in combat durante un popup o dopo l'autorizzazione: non deve partire
   alcuna azione all'uscita. Disabilita ogni modulo e verifica i clic normali.
8. Fai `/reload`: le preferenze e i lock devono restare in Draxtilities e non
   attivare modifiche al funzionamento originale di EUI.

## Sviluppo e API usate

Il sorgente di Draxtilities è in questa cartella. Non accede a `_ModuleNS`, agli
internals delle bag o ai popup del fork e non sostituisce funzioni EUI.
L'unica lettura del vecchio servizio riguarda il rilevamento di una protezione
integrata ancora in esecuzione, per impedirne la duplicazione.

- Plugin API ufficiale, documentata in `PLUGINS_API.md` nella cartella o nel repository di EllesmereUI: RegisterPlugin,
  OpenPlugin, Widgets, ricerca e refresh della pagina del plugin.
- Skinning API, documentata in `SKINNING_API.md` di EllesmereUI: soltanto frame creati da Draxtilities.
- `EUI_Bags.RegisterItemOverlayIcon` / `UnregisterItemOverlayIcon`: API pubblica
  documentata in `EUI_Bags_Slots.lua` di EllesmereUIBags; nessuna modifica ai pulsanti Blizzard.
- API Blizzard degli oggetti e definizioni native di cancellazione, consultate
  nel [sorgente UI Blizzard](https://github.com/Gethe/wow-ui-source).

Il repository contiene il solo sorgente di Draxtilities. Il workflow GitHub
genera lo ZIP installabile e i metadati per WoWUp a ogni push di un tag di versione.
Per i comandi e il flusso di pubblicazione vedi
[RELEASING.md](https://github.com/draxas/Draxtilities/blob/main/RELEASING.md).

Per controllare manifest e versione prima della pubblicazione:

```text
python scripts/validate_release.py
```

## Licenza

Il codice originale di Draxtilities è distribuito con [licenza MIT](LICENSE).
World of Warcraft ed EllesmereUI restano dei rispettivi titolari; questo
repository non ne include il codice né gli asset.
