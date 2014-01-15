@app = angular.module "bluffApp", ["firebase"]

@app.factory 'Cards', ->
  ["1 club",
    "2 club"
  ]

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
  ref = new Firebase('https://bluff.firebaseio.com/moves')
  cardsRef = new Firebase('https://bluff.firebaseio.com/cards')
  metaRef = new Firebase('https://bluff.firebaseio.com/meta')
  roundRef = new Firebase('https://bluff.firebaseio.com/round')
  @cards = $firebase cardsRef
  @meta = $firebase metaRef
  @round = $firebase roundRef
  @playerName = "Gerald"
  @player = 0
  @selectedCards = []
  console.log(@meta)

  $scope.selectCard = (card) =>
    @selectedCards.push(card)

  $scope.playCards = =>
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

    @selectedCards = []
    @meta.curTurn = (@meta.curTurn + 1) % @meta.numPlayers

    @round.$save()
    @cards.$save()
    @meta.$save()

  $scope.callBluff = (moves) =>
    moves.$add
      user: "Gerald"
      numeral: "Ace"
      count: 2
  
  # round:
  #   numeral: 5 // if numeral has not been set, then it is first move of set
  #   moves: [ 
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

    @round.moves = []
    delete @round.numeral
    @cards.$set cards
    @meta.$set meta
    @round.$save()
    console.log(@round)
  return this

@app.directive "message", ->
  restrict: 'E'
  template: '<div>Div contents go here</div>'
