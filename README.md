# Draxtilities

Draxtilities aggiunge i lucchetti agli oggetti nelle borse di EllesmereUI.
Puoi proteggere una copia di un oggetto e lasciare libere le altre, anche se
sono identiche. I moduli aggiungono conferme per vendita, eliminazione, aste
e riciclo nelle operazioni elencate sotto.

## Requisiti

- World of Warcraft Retail.
- EllesmereUI 9.7.3 o successiva.
- EllesmereUIBags per usare Bag Locks nelle borse.

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

## Primo utilizzo

1. Digita `/dt` per aprire le opzioni di Draxtilities.
2. Nella pagina **Modules**, abilita i moduli che vuoi usare. Al primo avvio sono tutti disabilitati.
3. Per selezionare gli oggetti dalle borse, abilita **Bag Locks**,
   chiudi e riapri le borse, poi digita `/dt lock`.
4. Fai clic sinistro sugli oggetti da proteggere o sbloccare.
   Premi Esc, fai clic destro su un oggetto o usa **Done** per uscire dalla selezione.

La protezione è disponibile per gli oggetti non stackabili. Un materiale
stackabile non può essere protetto nemmeno quando ne possiedi un solo pezzo.
Prima di usare `/dt lock`, esci dalle modalità Junk o Pin delle borse EUI.
L'apertura del mercante e la chiusura delle borse terminano la selezione.

Puoi applicare e rimuovere i lucchetti anche dalla pagina **Items**, che elenca
le singole copie degli oggetti non stackabili nelle borse, comprese quelle che
EUI raggruppa nella stessa icona. Per aggiungere un lucchetto deve essere attivo
almeno un modulo. Con **Protected only** attivo vengono mostrati tutti i lucchetti
salvati, anche quando la copia non è più nelle borse del personaggio.
Usa **Refresh** per aggiornare l'elenco.

## Moduli

| Modulo | Operazioni coperte |
|---|---|
| Bag Locks | Lucchetti e selezione nelle borse EUI; conferma della vendita con clic destro al mercante. |
| Cursor Safeguards | Conferma quando trascini un oggetto protetto nel mondo per eliminarlo o sul mercante per venderlo. Per gli oggetti che richiedono DELETE, la conferma EUI arriva dopo quella digitata. |
| Native Junk Sale | Pulsante Blizzard **Sell All Junk**. |
| Native Auctions | Pulsante **Post** della finestra aste Blizzard per oggetti non stackabili. Con copie protette corrispondenti nelle borse, si mette all'asta una copia alla volta. |
| Native Scrapping | Pulsante di riciclo della finestra Blizzard. |

Per **Native Junk Sale**, **Native Auctions** e **Native Scrapping**, quando
l'azione coinvolge copie protette:

1. Premi il pulsante dell'azione.
2. Conferma il popup EUI.
3. Premi di nuovo il pulsante dell'azione per completarla.

Prima dell'esecuzione vengono ricontrollati gli oggetti selezionati e i dati
dell'operazione, compresi prezzo, durata e quantità delle aste.
Una selezione o un'operazione diversa richiede una nuova conferma.
Le operazioni senza oggetti protetti procedono normalmente.

Le protezioni sono attive fuori dal combattimento. Quando entri in combattimento,
conferme e autorizzazioni vengono annullate. Per riprendere un'operazione
interrotta, avviala di nuovo dopo il combattimento.

## Comandi

| Comando | Azione |
|---|---|
| `/dt` o `/draxtilities` | Apre le opzioni. |
| `/dt items` | Apre la pagina Items. |
| `/dt lock` | Attiva o termina la selezione dei lucchetti nelle borse. Richiede Bag Locks. |
| `/dt cursor` | Protegge o sblocca la copia sul cursore. Richiede almeno un modulo attivo. |

Puoi usare `/dt lock` in una macro e assegnarle un tasto.

## Limiti della protezione

I lucchetti coprono le operazioni indicate nella tabella dei moduli.
Queste azioni restano escluse:

- Vendite automatiche e pulsante **Sell Junk** di EllesmereUI.
- Apertura automatica dei contenitori.
- Disincantamento, altri incantesimi sugli oggetti ed EUI Quick Actions.
- Posta, scambi, creazione degli oggetti e consegne delle quest.
- Vendita, eliminazione, aste e riciclo avviati da macro o pulsanti di altri addon.

Se usi i lucchetti, disabilita la vendita automatica in EUI e negli altri addon.
Controlla la copia scelta prima di usare una delle azioni escluse.
Bag Locks blocca il clic su un oggetto protetto quando stai scegliendo il
bersaglio di un incantesimo. Per usarlo come bersaglio, rimuovi prima il lucchetto.
Questo controllo non copre gli altri modi di avviare l'incantesimo.

Quando EUI raggruppa più copie in una sola icona, il lucchetto si riferisce
alla copia visualizzata. Usa **Items** per vedere e gestire le altre copie.

## Salvataggio dei lucchetti

Impostazioni e lucchetti vengono conservati tra sessioni e reload nel file
`WTF/Account/<account>/SavedVariables/Draxtilities.lua`.

I lucchetti restano nel registro anche quando la copia viene spostata,
equipaggiata, venduta o non si trova nelle borse del personaggio.
La rimozione automatica riguarda le eliminazioni e i ricicli osservati da
Draxtilities. Per rimuovere un lucchetto che non serve più, usa
**Remove protection** nella pagina Items.

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
