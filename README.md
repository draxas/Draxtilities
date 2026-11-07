# Draxtilities

Draxtilities aggiunge i lucchetti agli oggetti nelle borse di EllesmereUI.
Puoi proteggere una copia di un oggetto e lasciare libere le altre, anche se
sono identiche. I moduli aggiungono conferme per vendita, eliminazione, aste
e riciclo nelle operazioni elencate sotto.

## Requisiti

- World of Warcraft Retail.
- EllesmereUI 9.7.3 o successiva.
- EllesmereUIBags per i controlli e la selezione dei lucchetti nelle borse EUI.

## Installazione

### WoWUp

Seleziona il client Retail e apri **Get Addons → Install from URL**, poi incolla:

```text
https://github.com/draxas/Draxtilities
```

WoWUp usa le [release del progetto](https://github.com/draxas/Draxtilities/releases)
per gli aggiornamenti. Puoi installare le nuove versioni con **Update** o
abilitare gli aggiornamenti automatici.

### Manuale

Scarica lo ZIP dell'addon dalla pagina
[Releases](https://github.com/draxas/Draxtilities/releases) ed estrai la cartella
`Draxtilities` in `_retail_/Interface/AddOns`.
Il file TOC deve trovarsi in `AddOns/Draxtilities/Draxtilities.toc`.
Usa il pacchetto dell'addon allegato alla release, anziché gli archivi **Source code**.

## Item Protection

Draxtilities raccoglie funzionalità indipendenti, ciascuna con le proprie
impostazioni. Il modulo disponibile al momento è **Item Protection**, disattivato
al primo avvio.

### Primo utilizzo

1. Apri le opzioni di EllesmereUI e seleziona **Draxtilities → Item Protection**,
   oppure digita `/dt`.
2. In **Settings**, attiva **Enable Item Protection**.
3. Apri le borse EUI e premi il **lucchetto dorato** nella fascia inferiore.
   Puoi usare anche **Lock or unlock bag items** in Settings.
   Se hai appena attivato i controlli delle borse, chiudi e riapri le borse una volta.
4. Fai clic sugli oggetti da proteggere o sbloccare. **Done**, Esc o un clic
   destro terminano la selezione.

La protezione è disponibile per gli oggetti non stackabili. Un materiale
stackabile non può essere protetto nemmeno quando ne possiedi un solo pezzo.
Esci dalle modalità Junk o Pin delle borse EUI prima di selezionare i lucchetti.
L'apertura del mercante e la chiusura delle borse terminano la selezione.

Il lucchetto Draxtilities segue la finestra delle borse, anche quando la sposti
o ne cambi la scala. Il clic sinistro attiva o termina la selezione; il destro
apre Items. Durante la selezione il lucchetto ha uno sfondo verde.
Il pulsante rimane nascosto quando i controlli delle borse sono disattivati o
sei in combattimento. Se la fascia inferiore non ha spazio libero tra valute,
oro e controlli della finestra, il pulsante viene nascosto: la selezione rimane
disponibile in Settings e tramite bind.

### Settings

**Enable Item Protection** controlla l'intera funzionalità. Disattivandolo si
spengono tutte le azioni e il bind, conservando i lucchetti e le preferenze.
Le opzioni in **Actions** scelgono quali ingressi proteggere; non sono moduli
separati di Draxtilities.

| Opzione | Funzione |
|---|---|
| EUI bag controls | Icone, pulsante di selezione, conferma delle vendite manuali e blocco delle spell puntate con un clic su una copia protetta nelle borse, incluso Disenchant. Richiede EllesmereUIBags. |
| Dragged item sales and deletion | Conferma quando trascini una copia protetta nel mondo per eliminarla o sul mercante per venderla. La conferma EUI segue quella DELETE, quando richiesta. |
| Sell All Junk button | Pulsante Blizzard **Sell All Junk**. |
| Auction Post button | Pulsante **Post** della finestra aste Blizzard per oggetti non stackabili. Con copie protette corrispondenti nelle borse, si mette all'asta una copia alla volta. |
| Scrap button | Pulsante di riciclo della finestra Blizzard. |

Al primo avvio le azioni sono preselezionate, ma rimangono inattive finché non
abiliti Item Protection. L'aggiornamento conserva le vecchie scelte: se almeno
una protezione era già attiva, Item Protection rimane attivo con quelle sole
azioni.

Per i pulsanti **Sell All Junk**, **Post** e riciclo, con copie protette:

1. Premi il pulsante dell'azione.
2. Conferma il popup EUI.
3. Premi di nuovo il pulsante dell'azione per completarla.

Prima dell'esecuzione vengono ricontrollati gli oggetti e i dati dell'operazione,
compresi prezzo, durata e quantità delle aste. Cambiare l'operazione richiede
un'altra conferma. Senza copie protette, l'azione procede normalmente.

Le protezioni sono attive fuori dal combattimento. Entrare in combattimento
annulla conferme e autorizzazioni; nessuna azione viene ripresa automaticamente
alla sua uscita.

### Selezione con la tastiera

In Settings, **Selection shortcut** permette di scegliere un tasto per la stessa
selezione nelle borse. Premi una combinazione e poi **Save shortcut**. Il dialogo
mostra l'eventuale azione già assegnata; **Clear shortcut** rimuove il bind,
mentre Esc o **Cancel** lasciano invariata la scelta.

Il bind richiede Item Protection e **EUI bag controls** attivi e funziona fuori
dal combattimento. Disattivando i controlli delle borse o l'intero modulo, il
tasto torna alla normale assegnazione di WoW. La combinazione resta salvata per
la successiva attivazione. Al primo avvio non è assegnato alcun tasto.
Il combattimento annulla anche la scelta di un nuovo bind senza salvarlo.

### Items

Items elenca solo le copie già protette, comprese quelle assenti dalle borse.
**Search locked items** filtra l'elenco a ogni carattere, senza premere Invio.
I risultati sono ordinati per nome.

Ogni riga mostra l'icona, il nome e la posizione della copia. Per quelle assenti
riporta il proprietario salvato e un suffisso del GUID per distinguerle.
Passando il mouse sull'icona compare il tooltip WoW dell'oggetto. Se la copia
si è spostata, viene usato il link salvato anziché mostrare un'altra copia
rimasta nello slot.

**Unlock** rimuove il lucchetto, anche se la copia è assente o Item Protection
è disattivato. Per aggiungere lucchetti usa la selezione nelle borse o `/dt cursor`.

## Comandi

| Comando | Azione |
|---|---|
| `/dt` o `/draxtilities` | Apre le opzioni. |
| `/dt items` | Apre la pagina Items. |
| `/dt lock` | Attiva o termina la selezione dei lucchetti nelle borse. Richiede EUI bag controls. |
| `/dt cursor` | Protegge o sblocca la copia sul cursore. Richiede un'azione di Item Protection attiva. |

Il bind configurabile in Settings permette di usare la selezione senza
comandi in chat. `/dt lock` rimane disponibile anche per le macro.

## Limiti della protezione

I lucchetti coprono le operazioni indicate nella tabella delle azioni.
Queste azioni restano escluse:

- Vendite automatiche e pulsante **Sell Junk** di EllesmereUI.
- Apertura automatica dei contenitori.
- Incantesimi sugli oggetti applicati direttamente allo slot da macro,
  EUI Quick Actions o altri ingressi esterni al puntamento manuale nelle borse EUI.
- Posta, scambi, creazione degli oggetti e consegne delle quest.
- Vendita, eliminazione, aste e riciclo avviati da macro o pulsanti di altri addon.

Se usi i lucchetti, disabilita la vendita automatica in EUI e negli altri addon.
Controlla la copia scelta prima di usare una delle azioni escluse.
Con EUI bag controls attivo, lanciare Disenchant e poi fare clic su una copia
protetta nelle borse annulla il puntamento e conserva il lucchetto. Lo stesso
blocco vale per le altre spell puntate manualmente su una copia protetta.
Per usarla come bersaglio, rimuovi prima il lucchetto. Questo controllo non
intercetta EUI Quick Actions, macro o spell già applicate allo slot da altri addon.

Quando EUI raggruppa più copie in una sola icona, il lucchetto si riferisce
alla copia visualizzata. **Items** elenca ogni copia già protetta, anche quelle
nascoste dal raggruppamento; non permette di proteggere copie ancora senza lock.

## Salvataggio dei lucchetti

Impostazioni e lucchetti vengono conservati tra sessioni e reload nel file
`WTF/Account/<account>/SavedVariables/Draxtilities.lua`.

I lucchetti restano nel registro anche quando la copia viene spostata,
equipaggiata, venduta o non si trova nelle borse del personaggio.
La rimozione automatica riguarda le eliminazioni e i ricicli osservati da
Draxtilities. Per rimuovere un lucchetto che non serve più, usa
**Unlock** nella pagina Items.

## Segnalazioni e sviluppo

Per segnalare un problema, apri una
[issue](https://github.com/draxas/Draxtilities/issues) indicando versione di
Draxtilities ed EllesmereUI, modulo attivo e passaggi per riprodurlo.

La mappa del codice e le convenzioni di sviluppo sono in
[AGENTS.md](https://github.com/draxas/Draxtilities/blob/main/AGENTS.md).
[RELEASING.md](https://github.com/draxas/Draxtilities/blob/main/RELEASING.md)
contiene i comandi di verifica, le prove nel client e la procedura di pubblicazione.

## Licenza

[MIT](LICENSE).
