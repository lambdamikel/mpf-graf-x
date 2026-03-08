#define VERSION  "   * V1.6 *  " 
#define DATE     "  10-26-2025 "  

//
//
//

#include <avr/pgmspace.h>
#include <avr/wdt.h>

#include <Adafruit_GFX.h>    // Core graphics library
#include <Adafruit_ST7735.h> // Hardware-specific library for ST7735
#include <Adafruit_ST7789.h> // Hardware-specific library for ST7789
#include <SPI.h>

//
//
//

#define BV(bit) (1 << (bit))
#define toggleBit(byte, bit)  (byte ^= BV(bit))
#define setBit(byte, bit) (byte |= BV(bit)) 
#define clearBit(byte, bit) (byte &= ~BV(bit))

#define IOREQ_PIN      PINC
#define IOREQ_WRITE    PC7 

#define RESET_PIN      PINC
#define RESET_PIN_NO   PC6

//
//
//

#define _Z80_READY PB1 
#define z80_run  DDRB = 0b10111101 
#define z80_halt DDRB = 0b10111111, clearBit(PORTB, _Z80_READY) 

#define bit_is_set(sfr, bit) (_SFR_BYTE(sfr) & _BV(bit))
#define bit_is_clear(sfr, bit) (!(_SFR_BYTE(sfr) & _BV(bit)))
#define loop_until_bit_is_set(sfr, bit) do { } while (bit_is_clear(sfr, bit))
#define loop_until_bit_is_clear(sfr, bit) do { } while (bit_is_set(sfr, bit))

//
//
//

GFXcanvas1 canvas(160, 128);

//
//
//

void wdt_init(void)
{

  cli();

  wdt_reset();
  MCUSR &= ~(1 << WDRF);
  WDTCSR |= (1 << WDCE) | (1 << WDE);
  WDTCSR = 0x00;

  sei();
   
  return;

}  

#define RESET PIN_PC6

#define soft_reset() do { wdt_enable(WDTO_15MS); for(;;) {}} while(0) 

void process_reset(void) {
  soft_reset(); 
}

//
// SPI TFT 
//

#define SCK     PIN_PB7
#define MOSI    PIN_PB5

#define TFT_CS        PIN_PB3
#define TFT_RST       PIN_PB2
#define TFT_DC        PIN_PB0

Adafruit_ST7735 tft = Adafruit_ST7735(TFT_CS, TFT_DC, TFT_RST);

//
//
//

float p = 3.1415926;

#define WRITE PIN_PC7

//
// OUTPUTS 
//

#define LED PIN_PC3

#define SDA PIN_PC1
#define SCL PIN_PC0

#define O7 PIN_PD7
#define O6 PIN_PD6
#define O5 PIN_PD5
#define O4 PIN_PD4
#define O3 PIN_PD3
#define O2 PIN_PD2
#define O1 PIN_PC5
#define O0 PIN_PC4 

//
// UART
//

#define TX PIN_PD1
#define RX PIN_PD0

//
// I2C 
// 

#define SDA PIN_PC1
#define SCL PIN_PC0

//
// Z80 HALT
// 

#define Z80_RDY	PIN_PB1

//
//
//

#define I7 PIN_PA7
#define I6 PIN_PA6
#define I5 PIN_PA5
#define I4 PIN_PA4
#define I3 PIN_PA3
#define I2 PIN_PA2
#define I1 PIN_PA1
#define I0 PIN_PA0

#define PORTAx 0

#define TO_CPC_2to7   PORTD
#define TO_CPC_0to1   PORTC // PC5 = Bit 1, PC4 = Bit 0 

#define DATA_TO_CPC(arg){  TO_CPC_2to7 = ( 0b11111100 & arg ); TO_CPC_0to1 = ( 0b00000011 & arg ) << 4 ; }

uint8_t input = 0; 

//
//
//

void testdrawrects(uint16_t color) {
  tft.fillScreen(ST77XX_BLACK);
  for (int16_t x=0; x < tft.width(); x+=6) {
    tft.drawRect(tft.width()/2 -x/2, tft.height()/2 -x/2 , x, x, color);
  }
}

//
//
//

#define ST77XX_BLACK 0x0000
#define ST77XX_WHITE 0xFFFF
#define ST77XX_RED 0xF800
#define ST77XX_GREEN 0x07E0
#define ST77XX_BLUE 0x001F
#define ST77XX_CYAN 0x07FF
#define ST77XX_MAGENTA 0xF81F
#define ST77XX_YELLOW 0xFFE0
#define ST77XX_ORANGE 0xFC00

//
//
//

#define BUFF_SIZE 8192

volatile uint8_t buffer[BUFF_SIZE] = {};

//
//
//

uint16_t col_array[] = {
  ST77XX_BLACK, 
  ST77XX_WHITE, 
  ST77XX_RED, 
  ST77XX_GREEN, 
  ST77XX_BLUE, 
  ST77XX_CYAN, 
  ST77XX_MAGENTA, 
  ST77XX_YELLOW, 
  ST77XX_ORANGE }; 

//
//
//

void setup() {

  tft.initR(INITR_BLACKTAB);
  //tft.setSPISpeed(1000000);
  tft.setSPISpeed(16000000);

  MCUSR = 0;
  MCUSR = 0;

  //wdt_init();

  // disable JTAG ! SET IT TWICE REALLY!!!
  MCUCR=0x80;// for the atmega644
  MCUCR=0x80;// for the atmega644
   
  randomSeed(analogRead(0));
  pinMode(LED, OUTPUT);

  pinMode(O7, OUTPUT); 
  pinMode(O6, OUTPUT); 
  pinMode(O5, OUTPUT); 
  pinMode(O4, OUTPUT); 
  pinMode(O3, OUTPUT); 
  pinMode(O2, OUTPUT); 
  pinMode(O1, OUTPUT); 
  pinMode(O0, OUTPUT); 

  portMode(PORTAx, INPUT);
  
  pinMode(WRITE, INPUT);    
  pinMode(RESET, INPUT_PULLUP);

  z80_run;

  for (uint16_t i = 0; i < 0x100; i++) {
    DATA_TO_CPC(i);
    delay(1); 
  }
  DATA_TO_CPC(0);

}

//
//
//

void loop() {

  z80_halt; 

  tft.setRotation(1); 
  tft.fillScreen(ST77XX_BLACK);

  testdrawrects(ST77XX_YELLOW); 
  delay(200);
  testdrawrects(ST77XX_BLUE); 
  delay(200);
  testdrawrects(ST77XX_RED); 
  delay(200);

  tft.setTextSize(2);
  tft.setCursor(0, 0);
  tft.setTextColor(ST77XX_WHITE);

  tft.println("-------------");
  tft.println("  Microprof. ");
  tft.println("    MPF-1    ");
  tft.println(" VDP Display ");
  tft.println(VERSION); 
  tft.println(DATE); 
  tft.println(" LambdaMikel ");
  tft.println("-------------");
  
  delay(2000);
  
  testdrawrects(ST77XX_YELLOW); 
  delay(200);
  testdrawrects(ST77XX_BLUE); 
  delay(200);
  testdrawrects(ST77XX_RED); 
  delay(200);

  int w = tft.width()-2;
  int h = tft.height()-2;

  tft.drawLine(1, 1, w, h, ST77XX_YELLOW);
  tft.drawLine(w, 1, 1, h, ST77XX_YELLOW);
  delay(500);

  tft.fillScreen(ST77XX_BLACK);
  tft.setCursor(0, 0);
  tft.setTextColor(ST77XX_WHITE);

  uint16_t buf_index = 0; 
  uint16_t end_index = 0;
  uint16_t start_index = 0;
  
  for (uint16_t i = 0; i < 0x100; i++) {
    DATA_TO_CPC(i);
    delay(1); 
  }
  DATA_TO_CPC(0);

  //
  //
  //
  
  canvas.fillScreen(ST77XX_BLACK); // Clear canvas (not display)
  tft.drawBitmapFast(0, 0, canvas.getBuffer(), canvas.width(), canvas.height(), ST77XX_WHITE, ST77XX_BLACK);

  //
  //
  //
  
  cli();

  int x1 = 0; 
  int y1 = 0; 
  int x2 = 0; 
  int y2 = 0;
  int size = 0; 

  int col = ST77XX_YELLOW;
  int bcol = ST77XX_BLACK;

  char c = ' ';
  char text_buffer[512] = {0}; 
  uint16_t j = 0;
  uint16_t d = 0;
  
  z80_run; 

  bool armed = true;
  bool use_canvas = true;
  bool read_arg = false;
  bool show_buf_index = true; 
  uint8_t command = 0;

  uint16_t i = 0;
  uint16_t max_index = 0; 

  while (true) {
  
    if (armed && bit_is_set(IOREQ_PIN, IOREQ_WRITE)) {

      input = PINA;
          
      z80_halt;
      digitalWrite(LED, HIGH);

      armed = false; 

      if (read_arg) {
	
	read_arg = false;
	
	// read index arg for set start and end index 
	if (command == 0xF1)       
	  end_index = input; 

	else if (command == 0xF0) 
	  start_index = input;
	
	else if (command == 0xF2) {
	  // set fcol
	  col = input % 9;
	  col = col_array[col]; 	     
	  if (use_canvas) {
	    canvas.setTextColor(ST77XX_WHITE);
	  } else {
	    tft.setTextColor(col);
	    delay(0);
	  }
	}

	else if (command == 0xF3) {
	  bcol = input % 9;
	  bcol = col_array[bcol]; 	     	  
	}	
	command = 0;	  
      }

      else if (input == 0xFF) {
      
	// draw buffer

	i = start_index;
	max_index = end_index > (buf_index-1) ? (buf_index-1) : end_index; 
	
	while ( i <= max_index) {
	
	  uint8_t command = buffer[i++];
	  switch (command) {

	  case 0x80 : // clear screen black
	    if (use_canvas) {
	      // use this as synchronization too; first copy the current state to the screen!
	      // else we won't be able to draw the individual frames at the end
	      // tft.drawBitmapFast(0, 0, canvas.getBuffer(), canvas.width(), canvas.height(), col, bcol);
	      // no, use 0x84 now! 
	      canvas.fillScreen(ST77XX_BLACK);
	      //canvas.setRotation(1);
	    } else {
	      tft.fillScreen(bcol);
	      tft.setRotation(1);
	      delay(0);
	    }

	    break;
	    
	  case 0x81 : // clear screen COL
	    if (use_canvas) {
	      canvas.fillScreen(col);
	      //canvas.setRotation(1);
	    } else {
	      tft.fillScreen(col);
	      tft.setRotation(1);
	      delay(0);
	    }
	    break;

	  case 0x82 : // set palette color COL
	    col = buffer[i++] % 9;
	    col = col_array[col]; 	     
	    if (use_canvas) {
	      canvas.setTextColor(ST77XX_WHITE);
	    } else {
	      tft.setTextColor(col);
	      delay(0);
	    }
	    break;
	    
	  case 0x83 : // set color COL 
	    col = buffer[i++];
	    if (use_canvas) {
	      canvas.setTextColor(ST77XX_WHITE);
	    } else {
	      tft.setTextColor(col);
	      delay(0);
	    }
	    
	    break;
	   
	  case 0x84 : // copy canvas without clear screen, explicit syncronization
	    if (use_canvas) 
	      tft.drawBitmapFast(0, 0, canvas.getBuffer(), canvas.width(), canvas.height(), col, bcol);
	    
	    break;

	  case 0x85 : // pause 
	    d = buffer[i++];
	    delay(d*100);
	    
	    break; 
	    
	  case 0x90 : // plot x2, y2, palette col 
	    x2 = buffer[i++]; 
	    y2 = buffer[i++];
	    col = buffer[i++] % 9;
	    col = col_array[col];
	    if (use_canvas) {
	      canvas.drawPixel(x2, y2, ST77XX_WHITE);
	    } else {
	      tft.drawPixel(x2, y2, col);
	      delay(0);
	    } 
	    break;

	  case 0x91 : // plot x2, y2, col 
	    x2 = buffer[i++]; 
	    y2 = buffer[i++]; 
	    col = buffer[i++];
	    if (use_canvas) {
	      canvas.drawPixel(x2, y2, ST77XX_WHITE);
	    } else {
	      tft.drawPixel(x2, y2, col);
	      delay(0);
	    }
	    break; 

	  case 0x92 : // plot x1, y1, palette col 
	    x1 = buffer[i++]; 
	    y1 = buffer[i++];
	    col = buffer[i++] % 9;
	    col = col_array[col];
	    if (use_canvas) {
	      canvas.drawPixel(x1, y1, ST77XX_WHITE);
	    } else {
	      tft.drawPixel(x1, y1, col);
	      delay(0);
	    }
	    break;

	  case 0x93 : // plot x1, y1, col 
	    x1 = buffer[i++]; 
	    y1 = buffer[i++]; 
	    col = buffer[i++];
	    if (use_canvas) {
	      canvas.drawPixel(x1, y1, ST77XX_WHITE);
	    } else {
	      tft.drawPixel(x1, y1, col);
	      delay(0);
	    }
	    break; 
	  
	  case 0xa0 : // line x1, y1, x2, y2, COL 
	    x1 = buffer[i++]; 
	    y1 = buffer[i++]; 
	    x2 = buffer[i++]; 
	    y2 = buffer[i++];
	    if (use_canvas) {	      
	      canvas.drawLine(x1, y1, x2, y2, ST77XX_WHITE);
	    } else {
	      tft.drawLine(x1, y1, x2, y2, col);
	      delay(0);
	    }
	    break;

	  case 0xa1 : // line prev x2, y2 - x2, y2, COL 
	    x1 = x2; 
	    y1 = y2; 
	    x2 = buffer[i++]; 
	    y2 = buffer[i++];
	    if (use_canvas) {
	      canvas.drawLine(x1, y1, x2, y2, ST77XX_WHITE);
	    } else {
	      tft.drawLine(x1, y1, x2, y2, col);
	      delay(0);
	    }
	    break;

	  case 0xa2 : // line prev. x1, y1 - x2, y2, COL 
	    x2 = buffer[i++]; 
	    y2 = buffer[i++]; 
	    if (use_canvas) {
	      canvas.drawLine(x1, y1, x2, y2, ST77XX_WHITE);
	    } else {
	      tft.drawLine(x1, y1, x2, y2, col);
	      delay(0);
	    }
	    break;
	  
	  case 0xa3 : // line x1, y1, x2, y2, palette col 
	    x1 = buffer[i++]; 
	    y1 = buffer[i++]; 
	    x2 = buffer[i++]; 
	    y2 = buffer[i++];
	    col = buffer[i++] % 9;
	    col = col_array[col];
	    if (use_canvas) {
	      canvas.drawLine(x1, y1, x2, y2, ST77XX_WHITE);
	    } else {
	      tft.drawLine(x1, y1, x2, y2, col);
	      delay(0);
	    }
	    break;

	  case 0xa4 : // line x1, y1, x2, y2, col 
	    x1 = buffer[i++]; 
	    y1 = buffer[i++]; 
	    x2 = buffer[i++]; 
	    y2 = buffer[i++];
	    col = buffer[i++];
	    if (use_canvas) {
	      canvas.drawLine(x1, y1, x2, y2, ST77XX_WHITE);
	    } else {
	      tft.drawLine(x1, y1, x2, y2, col);
	      delay(0);
	    }
	    break; 
	  
	  case 0xa5 : // line - x2, y2, palette col  
	    x1 = x2; 
	    y1 = y2; 
	    x2 = buffer[i++]; 
	    y2 = buffer[i++];
	    col = buffer[i++] % 9;
	    col = col_array[col];
	    if (use_canvas) {
	      canvas.drawLine(x1, y1, x2, y2, ST77XX_WHITE);
	    } else {
	      tft.drawLine(x1, y1, x2, y2, col);
	      delay(0);
	    }
	    break;

	  case 0xa6 : // line - x2, y2, col  
	    x1 = x2; 
	    y1 = y2; 
	    x2 = buffer[i++]; 
	    y2 = buffer[i++];
	    col = buffer[i++];
	    if (use_canvas) {
	      canvas.drawLine(x1, y1, x2, y2, ST77XX_WHITE);	     
	    } else {
	      tft.drawLine(x1, y1, x2, y2, col);
	      delay(0);
	    }
	    break;
	  
	  case 0xb0 : // print char x1, y2, char 
	    x1 = buffer[i++]; 
	    y1 = buffer[i++]; 
	    c = buffer[i++];
	    if (use_canvas) {
	      canvas.setCursor(x1, y1);
	      canvas.print(c);
	    } else {
	      tft.setCursor(x1, y1);
	      tft.print(c);
	      delay(0);
	    }
	    break;
	    
	  case 0xc0 : // set text size 
	    size = buffer[i++];
	    if (use_canvas) {
	      canvas.setTextSize(size);
	    } else {
	      tft.setTextSize(size);
	      delay(0);
	    }
	    break;
	  
	  case 0xc1 : // set cursor x1, y1 
	    x1 = buffer[i++]; 
	    y1 = buffer[i++];
	    if (use_canvas) {
	      canvas.setCursor(x1, y1);
	    } else {
	      tft.setCursor(x1, y1);
	      delay(0);
	    }
	    break;

	  case 0xc2 : // print char cur settings 
	    c = buffer[i++];
	    if (use_canvas) {
	      canvas.print(c);
	    } else {
	      tft.print(c);
	      delay(0);
	    }	    
	    break;
	
	  case 0xc3 : // text wrap on / off 
	    c = buffer[i++];
	    if (use_canvas) {
	      canvas.setTextWrap(c);	     
	    } else {
	      tft.setTextWrap(c);
	      delay(0);
	    }
	    break;

	  case 0xd0 : // print string (0-terminated)
	    j = 0;           
	    do {
	      c = buffer[i % 512];	      
	      text_buffer[j] = c; 
	      i++;
	      j++; 
	    } while (c);

	    if (use_canvas) {
	      canvas.println(text_buffer);
	    } else {
	      tft.println(text_buffer);	    
	      delay(0);
	    }
	    break;	  

	  case 0xd1 : // println string (0-terminated) 
	    j = 0;
	    do {
	      c = buffer[i % 512];
	      text_buffer[j] = c; 
	      i++;
	      j++; 
	    } while (c);

	    if (use_canvas) {
	      canvas.print(text_buffer);
	    } else {
	      tft.print(text_buffer);
	      delay(0);
	    }
	    break;

	  case 0xe0 : // set background palette COL and clear screen
	    bcol = buffer[i++] % 9;
	    bcol = col_array[bcol]; 	     
	    break; 
	    
	  case 0xe1 : // set background COL and clear screen
	    bcol = buffer[i++];
	    break;

	  }
	  
	}

	// end while 

	if (show_buf_index) {
	  tft.setTextSize(1); 
	  tft.setCursor(2, 2); // looks better... not so close to the edge of the TFT
	  tft.setTextColor(col);
	  tft.printf("%d:[0 %d %d %d]/%d", use_canvas ? 1 : 0, start_index, max_index-1, end_index, buf_index-1);
	}

	// next time, start playback from current pointer pos. 
	start_index = max_index; 

	// end if 0xFF
	
      } else if (input == 0xFE) {
	// clear command buffer 
	buf_index = 0;
	end_index = 0;
	start_index = 0;
      } else if (input == 0xFD) {
	// reset start index 
	start_index = 0;
      } else if (input == 0xFC) {
	// double buffering on
	use_canvas = true;
      } else if (input == 0xFB) {
	// double buffering off
	use_canvas = false;
      } else if (input == 0xFA) {
	// query buffer index  
	DATA_TO_CPC(buf_index);
      } else if (input == 0xF9) {
	// set end index to full_buffer
	end_index = buf_index;
      } else if (input == 0xF8) {
	// set indexes for full_buffer playback
	start_index = 0; 
	end_index = buf_index;
      } else if (input == 0xF7) {
	// show buffer status on
	show_buf_index = true;
      } else if (input == 0xF6) {
	// show buffer status off
	show_buf_index = false;
      } else if (input == 0xF5) {
        // sync clear!
	if (use_canvas) 
	  canvas.fillScreen(ST77XX_BLACK);
	tft.fillScreen(bcol);
	tft.setRotation(1);
	delay(0);
	
	if (show_buf_index) {
	  tft.setTextSize(1); 
	  tft.setCursor(2, 2); // looks better... not so close to the edge of the TFT
	  tft.setTextColor(col);
	  tft.printf("%d:[0 %d %d %d]/%d", use_canvas ? 1 : 0, start_index, max_index-1, end_index, buf_index-1);
	}

      } else if (input == 0xF4) {
	// sync copy bitmap 
	if (use_canvas) 
	  tft.drawBitmapFast(0, 0, canvas.getBuffer(), canvas.width(), canvas.height(), col, bcol);
      } else if (input == 0xF3) {
	// set sync bcol 
	command = input;
	read_arg = true;
      } else if (input == 0xF2) {
	// set sync fcol 
	command = input;
	read_arg = true;
      } else if (input == 0xF1) {
	command = input;
	read_arg = true;
      } else if (input == 0xF0) {
	command = input;
	read_arg = true;
      } else {

	// asyncronous drawing command, < 0x80
	// put into command buffer
	  
	if (buf_index == BUFF_SIZE) {
	  // buffer full? ERROR! 
	  tft.setCursor(0, 8);
	  tft.println("*** ERROR");
	  tft.println("BUFFER FULL!");
	} else {
	  buffer[buf_index++] = input;
	  end_index=buf_index-1; 
	}
      }

      digitalWrite(LED, LOW);
    
      z80_run; 

    } else if (bit_is_clear(IOREQ_PIN, IOREQ_WRITE)) {

      armed = true;
     
    }
    
  }

}
