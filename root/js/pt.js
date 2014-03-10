$(document).ready(function() {

  // All external links in new window
  $("a[href^='http']").not('.noblank').each(function(){
    if(this.href.indexOf(location.hostname) == -1) {
      $(this).attr('target', '_blank');
    }
  });

  // switch all no-js classes to js classes
  $('.no-js').addClass('js').removeClass('no-js');

  // remove all js-remove elements
  $('.js-remove').remove();

  $('.useralert').each(function(){
    $(this).hide();
    $.pnotify({
      title: $(this).data("title"),
      text: $(this).data("text"),
      animated_speed: 'fast',
      type: $(this).data("type"),
    });
  });

});
