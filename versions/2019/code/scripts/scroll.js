var menuItems = new Array(); //array of menus
var section_tops = new Array(); //top of the sections statically on page load
var current_section = 0, //for menu animation
  new_section = 0; //for menu animation
var mainMenuHeight;
var mouseY = 100; //mouse coordinate
var prevScrollpos = window.pageYOffset;
var oldScrollPosition;








//event handlers for right and left arrow keys for 'body'
//move menus to right and left on keydown
function menuMove(event) {
  if(event.repeat)
    return;
  if (window.event.keyCode == 37 /*left key*/ ||
    (window.event.keyCode == 32 && window.event.shiftKey) /*shift+spacebar*/ ) {
    if (current_section > 0) {
      current_section--;
      $('#menu' + current_section)[0].click();
    }
  } else if (window.event.keyCode == 39 /*right key*/ ||
    (window.event.keyCode == 32 && !window.event.shiftKey) /*spacebar*/ ) {
    if (current_section < menuItems.length-1) {
      current_section++;
      $('#menu' + current_section)[0].click();
    }
  }
}









//event handler for scroll attached to 'body'
//change the selected menu depending on the scroll height
function menuSelect() {
  var newScrollPosition = $(window).scrollTop();

  //select the appropriate menu item based on scroll position
  new_section = 0;
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

  //show the menubar according to whether scrolled up or down
  if(mouseY <= mainMenuHeight){
    document.getElementById("mainMenu").style.top = 0;
  } else if (oldScrollPosition > newScrollPosition) {
    document.getElementById("mainMenu").style.top = 0;
  } else if( newScrollPosition > section_tops[0]){
    document.getElementById("mainMenu").style.top = "-" + mainMenuHeight + "px";
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
  }, 200, 'swing', function() {
    window.location = '#' + $target.attr('id');
  });
}












$(document).ready(function() {
  computeTops();

  $('a[href^="#"]').on('click', hyperlinkClickScrollAnimation);

  window.addEventListener('resize', computeTops);
  window.addEventListener('orientationchange', computeTops);
  window.addEventListener('scroll', menuSelect);

  document.body.addEventListener('mousemove',updateMouseY);
  document.body.addEventListener('keydown',menuMove);
});
