@app = angular.module "bluffApp", ["firebase"]

@app.filter 'cardToName', ->
  (card) ->
    suit = switch card.suit
      when 0 then "Clubs"
      when 1 then "Diamonds"
      when 2 then "Hearts"
      when 3 then "Spades"
    card.numeral + " of " + suit

@app.filter 'turnText', ->
  (curTurn, player, players) ->
    if players
      if players[curTurn] == player
        "Your move"
      else
        "Waiting for " + players[curTurn]
    else
      "Reconnecting..."

@app.filter 'cardsInCenter', ->
  (moves) ->

# Returns the numerals contained in a list of cards
@app.filter 'cardNumerals', ->
  (cards) ->
    return unless cards
    numerals = {}
    for card in cards
      numerals[card.numeral] = true
    (parseInt numeral for numeral in Object.keys numerals)

# Returns just the suits with a given numeral in a hand of cards
@app.filter 'suitsWithNumeral', ->
  (cards, numeral) ->
    (card.suit for card in cards when card.numeral == numeral)

@app.filter 'prettyNumeral', ->
  (numeral) ->
    if numeral == 1
      'A'
    else if numeral == 11
      'J'
    else if numeral == 12
      'Q'
    else if numeral == 13
      'K'
    else
      numeral

@app.filter 'prettySuit', ->
  (suit) ->
    ['♣', '♦', '♥', '♠'][suit]

@app.filter 'potCards', ->
  (round) ->
    return if !round or !round.moves
    sum = 0
    sum += move.cards.length for move in round.moves
    [0...sum]

@app.filter 'lastMovePrettify', ->
  (moveType) ->
    if moveType == 'BLUFF'
      'Bluff!'
    else if moveType == 'PASS'
      'Pass!'

@app.filter 'toRange', ->
  (num) ->
    [0...num]

@app.controller "GameCtrl", ($scope, $firebase, $timeout) ->
  @fb = $firebase new Firebase 'https://bluff.firebaseio.com'
  @loading = true
  @playerName = "Gerald"
  @player = prompt "Nick type 1, Andrew type 2 plz :)"
  @selectedCards = []
  @pressedPlay = false

  @fb.$on 'loaded', =>
    # Bug in fb where 'loaded' triggers but fb not loaded
    # make another 10 ms timeout to make sure content loaded
    $timeout =>
      @cards = @fb.$child 'cards'
      @meta = @fb.$child 'meta'
      @round = @fb.$child 'round'
      @loading = false
    , 100

  @updateTurn = =>
    return unless @fb && @fb.meta && @fb.meta.numPlayers
    @msg = if @fb.meta.curTurn == @player then 'Your move' else ''


  $scope.$watch 'game.fb.meta', @updateTurn

  $scope.$watch 'game.playerName', =>
    return unless @meta && @meta.players
    @player = @meta.players.indexOf @playerName

  @selectCard = (card) =>
    @selectedCards.push(card)

  @pass = =>
    @meta.curTurn = (@meta.curTurn + 1) % @meta.numPlayers
    @meta.lastMove[@player] =
      type: 'PASS'
    if @meta.curTurn == @round.moves[@round.moves.length - 1].player
      @round.moves = []
      delete @round.numeral
      @round.$save()
      @resetLastMoves()
    @meta.$save()
    @checkWin()

  @playCards = =>
    @pressedPlay = false
    @calcSelectedCards()
    console.log @selectedCards
    move =
      player: @player
      count: @selectedCount
      cards: @selectedCards
    
    if not @round['numeral']
      @round.numeral = @selectedNumeral
      @round.moves = []
    @round.moves.push move
    
    @cards[@player] = @cards[@player].filter (card) =>
      for selectedCard in @selectedCards
        if selectedCard.numeral == card.numeral and selectedCard.suit == card.suit
          return false
      true
    @cards[@player] = @cards[@player] || []

    @selectedCards = []
    @meta.curTurn = (@meta.curTurn + 1) % @meta.numPlayers
    @meta.lastMove[@player] =
      type: 'PLAY'
      count: @selectedCount

    @round.$save()
    @cards.$save()
    @meta.$save()
    @checkWin()

  @checkWin = =>
    if @round.moves.length == 0
      recentMove = null
    else
      recentMove = @round.moves[@round.moves.length - 1]
    for player in [0...@meta.numPlayers]
      if not @cards[player]? and (recentMove == null or recentMove.player != player)
        console.log "#{player} wins!"
        @meta.gameState =
          type: 'WIN'
          player: player

    @meta.$save()
        
  @clickAllCards = =>
    @selectedCards = angular.copy @cards[@player]

  @giveCards = (round, player) =>
    for move in round.moves
      for card in move.cards
        @cards[player].push(card)


  @callBluff = =>
    recentMove = @round.moves[@round.moves.length - 1]
    wrongCards = recentMove.cards.filter (card) =>
      card.numeral != @round.numeral

    if wrongCards.length > 0 or recentMove.count != recentMove.cards.length
      console.log "Good call"
      @giveCards @round, recentMove.player
    else
      console.log "Bad call"
      @giveCards @round, @player
      @meta.curTurn = recentMove.player

    @meta.lastMove[@player] =
      type: 'BLUFF'

    @round.moves = []
    delete @round.numeral
    @round.$save()
    @meta.$save()
    @cards.$save()
    @resetLastMoves()
    @checkWin()
  
  # round:
  #   numeral: 5 // if numeral has not been set, then it is first move of set
  #   moves: [        // the most recent moves are at end of list
  #     player: 0
  #     count: 3
  #     cards: [
  #       numeral: 5
  #       suit: 1,
  #       numeral: 10
  #       suit: 2,
  #       numeral: 1,
  #       suit: 3
  #     ],
  #     player: 1
  #     count: 3
  #     cards: [
  #       numeral: 10
  #       suit: 3,
  #       numeral: 10
  #       suit: 1
  #     ]
  #   ]
  # meta:
  #   gameState:
  #     type: 'WIN'
  #     player: 0
  #     // OR 
  #     type: 'LOBBY'
  #     // OR
  #     type: 'PLAYING'
  #
  #   numPlayers: numPlayers
  #   players: [
  #     "Gerald"
  #     "Nick"
  #     "Andrew"
  #   ]
  #   curTurn: 0
  #   lastMove:
  #     0:
  #       type: 'PLAY'
  #       count: 2
  #     1:
  #       type: 'PASS'
  #     2:
  #       type: 'CALL' # or 'PASS' or 'NONE'
  #
  # cards:
  #   0: [
  #     numeral: 2
  #     suit: 0,
  #     numeral: 3
  #     suit: 3
  #   ]
  #   1: [
  #     numeral: 4
  #     suit: 3,
  #     numeral: 2
  #     suit: 1
  #   ]

  # numeral - Card number from 1 to 13
  # suit - Suit value from 0 to 3, club, diamond, heart, spade respectively
  @restartGame = (numPlayers) =>
    deck = ({numeral: i % 13 + 1, suit: Math.floor i / 13} for i in [0...52])
    for i in [0...52]
      randI = Math.floor(Math.random() * 52)
      [deck[i], deck[randI]] = [deck[randI], deck[i]]
    cards = {}
    cards[playerNum] = [] for playerNum in [0...numPlayers]
    cards[i % numPlayers].push(deck[i]) for i in [0...52]

    meta =
      numPlayers: numPlayers
      players: [
        "Gerald"
        "Nick"
        "Andrew"
      ]
      curTurn: 0
      gameState:
        type: 'PLAYING'
      lastMove:
        0:
          type: 'NONE'
        1:
          type: 'NONE'
        2:
          type: 'NONE'

    @fb.round = {}
    @fb.$save()
    @cards.$set cards
    @meta.$set meta

  @resetLastMoves = =>
    @meta.lastMove =
      0:
        type: 'NONE'
      1:
        type: 'NONE'
      2:
        type: 'NONE'
    @meta.$save()

  @otherPlayers = =>
    [(@player + 1) % 3, (@player + 2) % 3]

  # UI Helper Methods below
  #
  
  @countNumeral = (numeral) =>
    x = 0
    x++ for card in @cards[@player] when card.numeral == numeral
    x
  
  @cardSelected = {}

  @calcSelectedCards = =>
    for card in @cards[@player]
      if @cardSelected[card.numeral] > 0
        @selectedCards.push card
        @cardSelected[card.numeral] -= 1

  @incrementCardSelected = (numeral) =>
    @cardSelected[numeral] ||= 0
    @cardSelected[numeral] = (@cardSelected[numeral] + 1) % (@countNumeral(numeral) + 1)

  return this
