var menuItems = new Array(); //array of menus
var section_tops = new Array(); //top of the sections statically on page load
var current_section = -1, //for menu animation
  new_section = 0; //for menu animation
var mainMenuHeight;
var mouseY = 100; //mouse coordinate
var prevScrollpos = window.pageYOffset;
var oldScrollPosition;




//event handlers for right and left arrow keys for 'body'
//move menus to right and left on keydown
function menuMove(event) {
  let lastKeyTime = 0;
  let currentTime = Date.now();
  if(currentTime - lastKeyTime <= 1000)
    return;
  lastKeyTime = currentTime;

  switch (event.key) {
    case "Right": 
    case "ArrowRight":
         if (current_section < menuItems.length-1) {
           current_section++;
           $('#menu' + current_section)[0].click();
         }
      break;
    case "Left": // IE/Edge specific value
    case "ArrowLeft":
      if (current_section > 0) {
            current_section--;
            $('#menu' + current_section)[0].click();
          }
      break;
    case "Escape":
      closeMainMenu();
      break; 
  }
}









//event handler for scroll attached to 'body'
//change the selected menu depending on the scroll height
function menuSelect() {
  var newScrollPosition = $(window).scrollTop();

  //select the appropriate menu item based on scroll position
  new_section = -1;
  menuItems.each(function(index, value) {
    if (newScrollPosition > section_tops[index] - 100) {
      new_section = index;
    }
  });

  if (new_section != current_section) {
    $("#menu" + current_section).removeClass("menuSelected");
    $("#menu" + new_section).addClass("menuSelected");
    current_section = new_section;
  }
  oldScrollPosition = newScrollPosition;
}










//compute the tops of various divs
function computeTops() {
  menuItems = $(".menuItem");
  mainMenuHeight = $("#mainMenu").outerHeight();

  menuItems.each(function(index, value) {
    section_tops[index] = $($(this).attr('href')).offset().top;
  });

  menuSelect();
}












function updateMouseY(event){
  mouseY = event.clientY;
  if(mouseY <= mainMenuHeight){
    document.getElementById("mainMenu").style.top = 0;
  }
}











//add scroll animation to the internal links in the menubar
function hyperlinkClickScrollAnimation(event){
  event.preventDefault();

  $target = $(this.hash);
  $('html, body').stop().animate({
    'scrollTop': $target.offset().top
  }, 300, 'swing', function() {
    window.location = '#' + $target.attr('id');
  });
}












$(document).ready(function() {
  createMainMenu();
  computeTops();

  $('a[href^="#"]').on('click', hyperlinkClickScrollAnimation);

  $('window').on('resize', computeTops);
  $('window').on('orientationchange', computeTops);
  $('window').on('scroll', menuSelect);

  $('body').on('mousemove',updateMouseY);
  $('body').on('keydown', menuMove);
  $('body').on('click', closeMainMenu);

  $('#mainMenu, #menuBtn').on('click', () => {
    event.stopPropagation();
  });
});
