class Card {
  int suit; // 0: Hearts, 1: Diamonds, 2: Clubs, 3: Spades
  int value; // 1 to 13 (Ace = 1, J = 11, Q = 12, K = 13)

  Card(int s, int v) {
    suit = s;
    value = v;
  }

  String getRankStr() {
    if (value == 1) return "A";
    if (value == 11) return "J";
    if (value == 12) return "Q";
    if (value == 13) return "K";
    return str(value);
  }
}

// Game state arrays
Card[] deck = new Card[52];
int deckSize = 52;

Card[] openPile = new Card[52];
int openSize = 0;

Card[] playerHand = new Card[10];
int playerSize = 0;

Card[] opponentHand = new Card[10];
int opponentSize = 0;

int playerScore = 0;
int opponentScore = 0;
int selectedCardIndex = -1;
String statusMessage = "Click deck to draw, or select a card.";

// Turn management
boolean isPlayerTurn = true; // true = player starts, false = opponent starts
boolean roundStartedByPlayer = true; // tracks who started the current round to alternate next round

// AI Turn Delay & Animation Variables
boolean waitingForAI = false;
int aiTurnTime = 0;

boolean animatingPlay = false;
int animStartTime = 0;
Card[] animCards = new Card[2];
int animCardCount = 0;
boolean pendingAITurn = false;

// Call It Pause State
boolean callItGameOverPaused = false;
boolean revealOpponentCards = false;

void settings() {
  size(1920, 1080);
}

void setup() {
  textAlign(CENTER, CENTER);
  // Randomize who starts the very first game
  roundStartedByPlayer = (random(1) >= 0.5);
  isPlayerTurn = roundStartedByPlayer;
  initGame();
}

void initGame() {
  deckSize = 0;
  for (int s = 0; s < 4; s++) {
    for (int v = 1; v <= 13; v++) {
      deck[deckSize] = new Card(s, v);
      deckSize++;
    }
  }
  for (int i = deckSize - 1; i > 0; i--) {
    int j = int(random(i + 1));
    Card temp = deck[i];
    deck[i] = deck[j];
    deck[j] = temp;
  }

  playerSize = 0;
  opponentSize = 0;
  for (int i = 0; i < 5; i++) {
    playerHand[playerSize] = deck[deckSize - 1];
    playerSize++;
    deckSize--;

    opponentHand[opponentSize] = deck[deckSize - 1];
    opponentSize++;
    deckSize--;
  }

  openPile[0] = deck[deckSize - 1];
  openSize = 1;
  deckSize--;

  selectedCardIndex = -1;
  waitingForAI = false;
  animatingPlay = false;
  callItGameOverPaused = false;
  revealOpponentCards = false;

  // Set turn to who started this round
  isPlayerTurn = roundStartedByPlayer;

  // If opponent starts, trigger AI turn right away
  if (!isPlayerTurn) {
    statusMessage = "Opponent's turn. Thinking...";
    startAITurn();
  } else {
    statusMessage = "Your turn. Click deck or select cards.";
  }
}

void draw() {
  background(40, 120, 60);

  if (callItGameOverPaused) {
    drawGameElements();
    
    // Draw semi-transparent overlay
    fill(0, 0, 0, 150);
    rect(0, 0, width, height);

    // Continue Button
    fill(200, 150, 0);
    stroke(255);
    rect(width / 2 - 150, height / 2 - 40, 300, 80, 10);
    fill(255);
    textSize(28);
    text("Continue", width / 2, height / 2);
    noStroke();
    return;
  }

  // Check 2-second animation timer
  if (animatingPlay && millis() - animStartTime >= 2000) {
    animatingPlay = false;
    for (int i = 0; i < animCardCount; i++) {
      openPile[openSize] = animCards[i];
      openSize++;
    }
    animCardCount = 0;
    
    if (pendingAITurn) {
      pendingAITurn = false;
      isPlayerTurn = false;
      waitingForAI = true;
      aiTurnTime = millis() + 2000;
    }
  }

  // Check AI delay timer
  if (waitingForAI && millis() >= aiTurnTime) {
    executeAITurn();
    waitingForAI = false;
  }

  drawGameElements();
}

void drawGameElements() {
  // Score top left
  fill(255);
  textSize(20);
  textAlign(LEFT, TOP);
  text("You: " + playerScore + " | Opponent: " + opponentScore, 30, 30);
  text("Current Turn: " + (isPlayerTurn ? "You" : "Opponent"), 30, 65);
  textAlign(CENTER, CENTER);

  // 1. Draw Opponent Hand (Top)
  fill(200, 50, 50);
  noStroke();
  rect(360, 40, 1200, 160, 12);
  fill(255);
  textSize(22);
  text("Opponent's Hand (" + opponentSize + " cards)", width / 2, 75);
  
  for (int i = 0; i < opponentSize; i++) {
    float cx = 420 + i * 110;
    float cy = 110;
    if (revealOpponentCards) {
      drawCard(cx, cy, 90, 130, opponentHand[i], false);
    } else {
      fill(100, 20, 20);
      stroke(255);
      rect(cx, cy, 90, 130, 8);
      fill(255);
      textSize(28);
      text("?", cx + 45, cy + 65);
      noStroke();
    }
  }

  // 2. Deck & Open Pile (Middle)
  fill(80);
  rect(760, 450, 140, 190, 10);
  fill(255);
  textSize(20);
  text("Deck\n(" + deckSize + ")", 830, 545);

  if (openSize > 0) {
    drawCard(1020, 450, 140, 190, openPile[openSize - 1], false);
  }

  // Played Cards Animation to the right of open deck
  if (animatingPlay) {
    for (int i = 0; i < animCardCount; i++) {
      drawCard(1180 + i * 150, 450, 130, 190, animCards[i], false);
    }
  }

  // 3. Player Hand (Bottom)
  fill(50, 80, 140);
  rect(360, 820, 1200, 210, 12);
  fill(255);
  textSize(22);
  text("Your Hand", width / 2, 850);

  for (int i = 0; i < playerSize; i++) {
    float x = 420 + i * 150;
    float y = 880;
    boolean isSelected = (selectedCardIndex == i);
    if (isSelected) {
      y -= 30;
    }
    drawCard(x, y, 110, 150, playerHand[i], isSelected);
  }

  // 4. Status and Call It Button (Bottom Right)
  fill(255);
  textSize(20);
  text(statusMessage, width / 2, 1045);

  boolean canCall = (playerSize == 1 && playerHand[0].value <= 5);
  if (canCall) {
    fill(200, 150, 0);
  } else {
    fill(120);
  }
  rect(1640, 1005, 180, 55, 8);
  fill(255);
  textSize(22);
  text("Call It", 1730, 1032);
}

void drawCard(float x, float y, float w, float h, Card c, boolean isSelected) {
  if (isSelected) {
    fill(255, 255, 0);
    rect(x - 4, y - 4, w + 8, h + 8, 8);
  }
  
  fill(255);
  stroke(0);
  rect(x, y, w, h, 8);

  if (c.suit == 0 || c.suit == 1) {
    fill(200, 0, 0);
  } else {
    fill(0);
  }

  textSize(18);
  textAlign(LEFT, TOP);
  text(c.getRankStr(), x + 8, y + 8);

  drawSuitSymbol(x + w / 2, y + h / 2, w * 0.3, c.suit);

  textAlign(CENTER, CENTER);
  noStroke();
}

void drawSuitSymbol(float cx, float cy, float sz, int suit) {
  if (suit == 0) {
    noStroke();
    ellipse(cx - sz * 0.22, cy - sz * 0.1, sz * 0.45, sz * 0.45);
    ellipse(cx + sz * 0.22, cy - sz * 0.1, sz * 0.45, sz * 0.45);
    triangle(cx - sz * 0.44, cy, cx + sz * 0.44, cy, cx, cy + sz * 0.5);
  } else if (suit == 1) {
    noStroke();
    quad(cx, cy - sz * 0.5, cx + sz * 0.35, cy, cx, cy + sz * 0.5, cx - sz * 0.35, cy);
  } else if (suit == 2) {
    noStroke();
    ellipse(cx, cy - sz * 0.2, sz * 0.35, sz * 0.35);
    ellipse(cx - sz * 0.22, cy + sz * 0.15, sz * 0.35, sz * 0.35);
    ellipse(cx + sz * 0.22, cy + sz * 0.15, sz * 0.35, sz * 0.35);
    rect(cx - sz * 0.08, cy, sz * 0.16, sz * 0.4);
  } else if (suit == 3) {
    noStroke();
    ellipse(cx - sz * 0.22, cy + sz * 0.1, sz * 0.45, sz * 0.45);
    ellipse(cx + sz * 0.22, cy + sz * 0.1, sz * 0.45, sz * 0.45);
    triangle(cx - sz * 0.44, cy, cx + sz * 0.44, cy, cx, cy - sz * 0.5);
    rect(cx - sz * 0.08, cy, sz * 0.16, sz * 0.4);
  }
}

void mousePressed() {
  if (callItGameOverPaused) {
    if (mouseX >= width / 2 - 150 && mouseX <= width / 2 + 150 && mouseY >= height / 2 - 40 && mouseY <= height / 2 + 40) {
      if (playerScore >= 100 || opponentScore >= 100) {
        playerScore = 0;
        opponentScore = 0;
        statusMessage = "New Game Started!";
      }
      // Alternate who starts the next round based on who started the current round
      roundStartedByPlayer = !roundStartedByPlayer;
      initGame();
    }
    return;
  }

  // Block player input if it's not player's turn or during animations
  if (!isPlayerTurn || waitingForAI || animatingPlay) return;

  // Click Deck (Action 1)
  if (mouseX >= 760 && mouseX <= 900 && mouseY >= 450 && mouseY <= 640) {
    if (selectedCardIndex != -1 && deckSize > 0) {
      Card discarded = playerHand[selectedCardIndex];
      playerHand[selectedCardIndex] = deck[deckSize - 1];
      deckSize--;
      
      animCards[0] = discarded;
      animCardCount = 1;
      animatingPlay = true;
      animStartTime = millis();
      pendingAITurn = true;
      
      selectedCardIndex = -1;
      statusMessage = "Drew card (Action 1). Opponent's turn next.";
    } else {
      statusMessage = "Select a card from your hand first to discard.";
    }
  }

  // Click Open Pile (Action 2)
  if (mouseX >= 1020 && mouseX <= 1160 && mouseY >= 450 && mouseY <= 640) {
    if (openSize > 0 && selectedCardIndex != -1) {
      Card topOpen = openPile[openSize - 1];
      Card chosen = playerHand[selectedCardIndex];
      
      if (chosen.value == topOpen.value && chosen.suit == topOpen.suit) {
        statusMessage = "Cannot play the exact card just taken!";
        return;
      }
      
      openSize--; 
      animCards[0] = chosen;
      animCardCount = 1;
      animatingPlay = true;
      animStartTime = millis();
      pendingAITurn = true;
      
      playerHand[selectedCardIndex] = topOpen;
      selectedCardIndex = -1;
      statusMessage = "Took open card (Action 2). Opponent's turn next.";
    } else {
      statusMessage = "Select a card from your hand to exchange.";
    }
  }

  // Click Player Hand Cards (Actions 3, 4, 5)
  for (int i = 0; i < playerSize; i++) {
    float x = 420 + i * 150;
    float y = 850;
    if (mouseX >= x && mouseX <= x + 110 && mouseY >= y && mouseY <= y + 150) {
      if (selectedCardIndex == -1) {
        selectedCardIndex = i;
        statusMessage = "Selected card rank " + playerHand[i].getRankStr() + ".";
      } else if (selectedCardIndex == i) {
        selectedCardIndex = -1;
        statusMessage = "Deselected card.";
      } else {
        Card c1 = playerHand[selectedCardIndex];
        Card c2 = playerHand[i];
        Card topOpen = openSize > 0 ? openPile[openSize - 1] : null;

        boolean isSameValue = (c1.value == c2.value);
        boolean isSum = (topOpen != null && (c1.value + c2.value == topOpen.value));
        boolean isDiff = (topOpen != null && (abs(c1.value - c2.value) == topOpen.value));

        if (isSameValue || isSum || isDiff) {
          if (isSum) {
            if (c1.value >= c2.value) {
              animCards[0] = c2;
              animCards[1] = c1;
            } else {
              animCards[0] = c1;
              animCards[1] = c2;
            }
          } else if (isDiff) {
            if (c1.value >= c2.value) {
              animCards[0] = c1;
              animCards[1] = c2;
            } else {
              animCards[0] = c2;
              animCards[1] = c1;
            }
          } else {
            int high = max(selectedCardIndex, i);
            int low = min(selectedCardIndex, i);
            animCards[0] = playerHand[high];
            animCards[1] = playerHand[low];
          }

          animCardCount = 2;
          animatingPlay = true;
          animStartTime = millis();
          pendingAITurn = true;

          int high = max(selectedCardIndex, i);
          int low = min(selectedCardIndex, i);
          for (int k = high; k < playerSize - 1; k++) {
            playerHand[k] = playerHand[k + 1];
          }
          playerSize--;
          for (int k = low; k < playerSize - 1; k++) {
            playerHand[k] = playerHand[k + 1];
          }
          playerSize--;

          selectedCardIndex = -1;
          statusMessage = "Move played! Opponent's turn next.";
        } else {
          statusMessage = "Invalid 2-card combination.";
          selectedCardIndex = -1;
        }
      }
    }
  }

  // Click 'Call It' Button (Action 6)
  if (mouseX >= 1640 && mouseX <= 1820 && mouseY >= 1005 && mouseY <= 1060) {
    if (playerSize == 1 && playerHand[0].value <= 5) {
      handlePlayerCallIt();
    }
  }
}

void startAITurn() {
  waitingForAI = true;
  aiTurnTime = millis() + 2000;
}

void executeAITurn() {
  if (opponentSize <= 0) return;

  // RULE REQUIREMENT: When opponent has only 1 card and it's 5 or lower, 
  // and player has more than 1 card in hand, always call it!
  if (opponentSize == 1 && opponentHand[0].value <= 5 && playerSize > 1) {
    executeAICallIt();
    return;
  }

  Card topOpen = openSize > 0 ? openPile[openSize - 1] : null;

  // AI Sum (Rule 4) - Highest value on top
  if (topOpen != null) {
    for (int i = 0; i < opponentSize; i++) {
      for (int j = i + 1; j < opponentSize; j++) {
        int v1 = opponentHand[i].value;
        int v2 = opponentHand[j].value;
        if (v1 + v2 == topOpen.value) {
          if (v1 >= v2) {
            animCards[0] = opponentHand[j];
            animCards[1] = opponentHand[i];
          } else {
            animCards[0] = opponentHand[i];
            animCards[1] = opponentHand[j];
          }
          animCardCount = 2;
          animatingPlay = true;
          animStartTime = millis();
          pendingAITurn = false;
          isPlayerTurn = true; // Pass turn back to player
          
          removeOpponentCards(j, i);
          statusMessage = "Opponent matched open card (Sum). Your turn.";
          return;
        }
      }
    }
  }

  // AI Difference (Rule 5) - Smaller value on top
  if (topOpen != null) {
    for (int i = 0; i < opponentSize; i++) {
      for (int j = i + 1; j < opponentSize; j++) {
        int v1 = opponentHand[i].value;
        int v2 = opponentHand[j].value;
        if (abs(v1 - v2) == topOpen.value) {
          if (v1 >= v2) {
            animCards[0] = opponentHand[i];
            animCards[1] = opponentHand[j];
          } else {
            animCards[0] = opponentHand[j];
            animCards[1] = opponentHand[i];
          }
          animCardCount = 2;
          animatingPlay = true;
          animStartTime = millis();
          pendingAITurn = false;
          isPlayerTurn = true; // Pass turn back to player
          
          removeOpponentCards(j, i);
          statusMessage = "Opponent matched open card (Diff). Your turn.";
          return;
        }
      }
    }
  }

  // AI Pair (Rule 3)
  for (int i = 0; i < opponentSize; i++) {
    for (int j = i + 1; j < opponentSize; j++) {
      if (opponentHand[i].value == opponentHand[j].value) {
        animCards[0] = opponentHand[j];
        animCards[1] = opponentHand[i];
        animCardCount = 2;
        animatingPlay = true;
        animStartTime = millis();
        pendingAITurn = false;
        isPlayerTurn = true; // Pass turn back to player
        
        removeOpponentCards(j, i);
        statusMessage = "Opponent played a pair. Your turn.";
        return;
      }
    }
  }

  // AI Fallback Blind Draw (Rule 1)
  if (deckSize > 0) {
    int highIdx = 0;
    for (int i = 1; i < opponentSize; i++) {
      if (opponentHand[i].value > opponentHand[highIdx].value) {
        highIdx = i;
      }
    }
    animCards[0] = opponentHand[highIdx];
    animCardCount = 1;
    animatingPlay = true;
    animStartTime = millis();
    pendingAITurn = false;
    isPlayerTurn = true; // Pass turn back to player

    opponentHand[highIdx] = deck[deckSize - 1];
    deckSize--;
    statusMessage = "Opponent drew blind. Your turn.";
  }
}

void removeOpponentCards(int high, int low) {
  int h = max(high, low);
  int l = min(high, low);
  for (int k = h; k < opponentSize - 1; k++) {
    opponentHand[k] = opponentHand[k + 1];
  }
  opponentSize--;
  for (int k = l; k < opponentSize - 1; k++) {
    opponentHand[k] = opponentHand[k + 1];
  }
  opponentSize--;
}

void handlePlayerCallIt() {
  int opponentSum = 0;
  for (int i = 0; i < opponentSize; i++) {
    opponentSum += opponentHand[i].value;
  }
  int playerCardVal = playerHand[0].value;

  revealOpponentCards = true;
  if (opponentSum > playerCardVal) {
    statusMessage = "You won! Press Continue.";
    opponentScore += opponentSum;
  } else {
    statusMessage = "Lost call! Press Continue.";
    playerScore += playerCardVal + 10;
  }

  callItGameOverPaused = true;
}

void executeAICallIt() {
  int playerSum = 0;
  for (int i = 0; i < playerSize; i++) playerSum += playerHand[i].value;
  int aiCardVal = opponentHand[0].value;

  revealOpponentCards = true;
  if (playerSum > aiCardVal) {
    statusMessage = "Opponent called it and won! Press Continue.";
    playerScore += playerSum;
  } else {
    statusMessage = "Opponent called it and lost! Press Continue.";
    opponentScore += aiCardVal + 10;
  }

  callItGameOverPaused = true;
}
