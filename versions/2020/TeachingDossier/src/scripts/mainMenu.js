// <a id="menu0" href="#itMe" class="menuItem menuSelected">It Me</a>

function createMainMenu(){

  $('body').append('<div id="mainMenu" class="closed"></div>');
  $('body').append(`
  <figure
    id="menuBtn"
    class="narrow-screen-only"
    onClick="toggleMainMenu()">
    <img src="src/content/images/hamburger-black.png" width="25px" height="25px" />
  </figure>`);

  var menuCount = 0;
  var subMenuCount = 1;

  $('#mainText > h1, #mainText > h2').each(function(index, value) {
    if ($(this).is('h1')){
      menuCount++;
      subMenuCount = 1;
      
      $menuItem = $("<a class='menuItem'></a>");

      $menuItem.html(menuCount + '. ' + $(this).html());
      $menuItem.attr("href", "#" + $(this).attr('id'));
      $menuItem.attr("id", "menu" + index);
      $menuItem.on('click', closeMainMenu);
    }  
    else {
      $menuItem = $("<a class='menuItem subMenuItem'></a>");

      $menuItem.html(menuCount + '.' + subMenuCount + '. ' + $(this).html());
      $menuItem.attr("href", "#" + $(this).attr('id'));
      $menuItem.attr("id", "menu" + index);
      $menuItem.on('click', closeMainMenu);
      subMenuCount++;
    }

    $('#mainMenu').append($menuItem);
  });
}




function openMainMenu() {
  $('#mainMenu').removeClass('closed');
  $('#mainMenu').addClass('open');
}

function closeMainMenu() {
  $('#mainMenu').removeClass('open');
  $('#mainMenu').addClass('closed');
}


function toggleMainMenu() {
  ($('#mainMenu').hasClass('closed')) ? openMainMenu() : closeMainMenu();
}
