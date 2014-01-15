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
    return unless moves
    sum = 0
    sum += move.cards.length for move in moves
    sum
      
@app.controller "GameCtrl", ($scope, $firebase) ->
  @fb = $firebase new Firebase 'https://bluff.firebaseio.com'
  @loading = true
  @playerName = "Gerald"
  @player = 0
  @selectedCards = []
  @fb.$on 'loaded', =>
    # Bug in fb where 'loaded' triggers but fb not loaded
    # make another 10 ms timeout to make sure content loaded
    setTimeout =>
      @cards = @fb.$child 'cards'
      @meta = @fb.$child 'meta'
      @round = @fb.$child 'round'
      @loading = false
    , 10

  $scope.$watch 'game.playerName', =>
    return unless @meta && @meta.players
    @player = @meta.players.indexOf @playerName

  $scope.selectCard = (card) =>
    @selectedCards.push(card)

  @pass = =>
    @meta.curTurn = (@meta.curTurn + 1) % @meta.numPlayers
    if @meta.curTurn == @round.moves[@round.moves.length - 1].player
      @round.moves = []
      delete @round.numeral
      @round.$save()
    @meta.$save()
    @checkWin()

  @playCards = =>
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
      @giveCards @round, recentMove.player
    else
      @giveCards @round, @player
      @meta.curTurn = recentMove.player

    @round.moves = []
    delete @round.numeral
    @round.$save()
    @meta.$save()
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
  $scope.restartGame = (numPlayers) =>
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

    @round.moves = []
    delete @round.numeral
    @round.$save()

    @cards.$set cards
    @meta.$set meta
  return this

@app.directive "message", ->
  restrict: 'E'
  template: '<div>Div contents go here</div>'
