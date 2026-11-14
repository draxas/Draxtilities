# Changelog

## 0.1.3

- Traduzione italiana di tutte le stringhe dell'interfaccia, dei tooltip, delle conferme e dei messaggi in chat, selezionata automaticamente sui client itIT. Inglese conservato sugli altri client; comandi e dati salvati invariati.
- Rimossa la chiamata protetta a SpellStopTargeting che causava il popup Blizzard durante il tentativo di disincantare un oggetto lockato.
- Il clic sulla copia protetta viene consumato senza eseguire la spell o togliere il lucchetto. Il puntamento rimane attivo e l'avviso indica soltanto che l'oggetto è bloccato.
- Il test delle spell rifiuta ora le chiamate dirette a SpellStopTargeting dagli handler Lua dell'addon.
- I controlli dei pulsanti nativi seguono i cambi di visibilità anche senza eventi delle borse. La chiusura del contesto annulla la relativa conferma e il permesso monouso, senza annullare conferme di altre azioni.

## 0.1.2

- Interruttore generale per Item Protection nella pagina Settings, con conservazione dei lucchetti e delle preferenze precedenti.
- Lucchetto dorato nella fascia inferiore delle borse EUI: clic sinistro per selezionare gli oggetti, destro per aprire Items. Segue la finestra e cerca spazio libero tra oro, valute e controlli nativi, senza modificare file EUI.
- Scorciatoia da tastiera configurabile per la selezione dei lucchetti, attiva solo con i controlli delle borse abilitati.
- Pagina Items semplificata con i soli oggetti protetti, ricerca live e tooltip WoW sull'icona dell'oggetto.
- Corretto il ripristino del focus nella ricerca: la digitazione non sostituisce più il testo a ogni carattere.
- Rimossa la pagina Coverage e chiariti i nomi delle opzioni; corretto l'allineamento della cella Scrap button.
- Il clic su un oggetto protetto con Disenchant o un'altra spell puntata manualmente nelle borse EUI annulla il puntamento. Quick Actions EUI e macro che applicano la spell direttamente allo slot restano escluse.

## 0.1.1

- Selezione dei lucchetti nelle borse di EllesmereUI con `/dt lock`.
- Gestione delle singole copie nella pagina Items, anche quando le borse le raggruppano.
- Conferme per la vendita di oggetti protetti al mercante, con clic destro o trascinamento.
- Conferme per l'eliminazione degli oggetti protetti, compresi quelli che richiedono DELETE.
- Controlli sui pulsanti Blizzard Sell All Junk, Post e riciclo.
- Salvataggio dei lucchetti tra sessioni e reload.
